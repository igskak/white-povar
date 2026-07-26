"""Internal-only Creator Studio drafts and tenant-bound image assets."""

from io import BytesIO
from pathlib import Path
from uuid import uuid4
from datetime import datetime, timezone

from PIL import Image, ImageOps, UnidentifiedImageError

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.v1.endpoints.auth import User, verify_firebase_token
from app.core.tenant import TenantContext, require_tenant_context
from app.schemas.studio import (
    StudioAsset, StudioAssetFinalize, StudioAssetUploadRequest,
    StudioAssetUploadTicket, StudioBrandDraft, StudioBrandDraftUpdate,
    StudioPublishResult, StudioRelease, StudioReleaseRequest,
    StudioReleaseStatusView, StudioReleaseUpdate, StudioRollbackRequest,
    StudioSession,
    StudioContentUpsert, StudioCollectionUpsert, StudioMerchandisingUpsert,
)
from app.services.database import supabase_service

router = APIRouter()
_BRAND_ASSET_BUCKET = 'studio-brand-assets'
_RECIPE_ASSET_BUCKET = 'studio-content-assets'
_MAX_DIMENSION = 6000
_MIN_DIMENSION = 320
_RECIPE_MIN_LONG_SIDE = 1200
_RECIPE_MIN_SHORT_SIDE = 800

_CATEGORY_IDS = {
    'закуски': '20000000-0000-0000-0000-000000000001',
    'перші страви': '20000000-0000-0000-0000-000000000002',
    'другі страви': '20000000-0000-0000-0000-000000000003',
    'гарніри': '20000000-0000-0000-0000-000000000004',
    'десерти': '20000000-0000-0000-0000-000000000005',
    'напої': '20000000-0000-0000-0000-000000000006',
    'хліб і випічка': '20000000-0000-0000-0000-000000000007',
    'салати': '20000000-0000-0000-0000-000000000008',
    'інше': '20000000-0000-0000-0000-000000000099',
}


async def require_studio_member(
    current_user: User = Depends(verify_firebase_token),
    tenant: TenantContext = Depends(require_tenant_context),
) -> tuple[User, TenantContext, str]:
    role = await supabase_service.get_studio_role(current_user.id, tenant.chef_id)
    if role not in {'editor', 'admin'}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail='Internal Studio access is required')
    return current_user, tenant, role


def _require_admin(membership: tuple[User, TenantContext, str]) -> tuple[User, TenantContext, str]:
    if membership[2] != 'admin':
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail='Studio admin access is required for releases')
    return membership


def _studio_row(row: dict) -> dict:
    """Keep internal rows explicit; do not reuse consumer serializers for drafts."""
    presentation = row.get('image_presentation')
    if not isinstance(presentation, dict) and row.get('image_url'):
        presentation = {
            'primary': {
                'url': row['image_url'],
                'alt_text': row.get('title') or '',
                'focal': {'x': 0.5, 'y': 0.5},
            },
            'featured': None,
            'detail': None,
        }
    return {
        **row,
        'id': str(row['id']),
        'chef_id': str(row['chef_id']),
        'image_presentation': presentation,
    }


def _category_id(category: str) -> str:
    return _CATEGORY_IDS.get(category.strip().lower(), _CATEGORY_IDS['інше'])


async def _resolve_recipe_image(
    value,
    *,
    tenant: TenantContext,
    existing: dict | None,
    role: str,
    primary: dict | None = None,
) -> dict | None:
    if value is None:
        return None
    focal = value.focal.model_dump()
    if value.use_primary:
        if primary is None:
            raise HTTPException(
                status_code=422,
                detail='A primary image is required before using a role override',
            )
        return {**primary, 'focal': focal}
    if value.asset_id:
        asset = await supabase_service.get_studio_asset(
            value.asset_id, tenant.chef_id)
        if (
            asset is None
            or asset.get('state') != 'ready'
            or asset.get('asset_kind', 'brand') != 'recipe'
            or not asset.get('url')
        ):
            raise HTTPException(
                status_code=422,
                detail='Recipe images must be ready recipe assets from this tenant',
            )
        return {
            'asset_id': str(asset['id']),
            'url': asset['url'],
            'alt_text': value.alt_text or asset.get('alt_text') or '',
            'width': asset.get('width'),
            'height': asset.get('height'),
            'focal': focal,
        }

    existing_presentation = (existing or {}).get('image_presentation') or {}
    existing_role = existing_presentation.get(role)
    allowed_url = (
        existing_role.get('url')
        if isinstance(existing_role, dict)
        else (existing or {}).get('image_url') if role == 'primary' else None
    )
    if not allowed_url or value.url != allowed_url:
        raise HTTPException(
            status_code=422,
            detail='Existing recipe image URL cannot be replaced directly',
        )
    return {
        **(existing_role if isinstance(existing_role, dict) else {}),
        'url': allowed_url,
        'alt_text': value.alt_text
        or (existing_role or {}).get('alt_text')
        or (existing or {}).get('title')
        or '',
        'focal': focal,
    }


async def _content_values(
    payload: StudioContentUpsert,
    tenant: TenantContext,
    existing: dict | None = None,
) -> dict:
    values = payload.model_dump(by_alias=False)
    values['category_id'] = _category_id(payload.category)
    values['tags'] = list(payload.tags)
    if payload.cuisine and not any(
        tag.lower() == payload.cuisine.lower() for tag in values['tags']
    ):
        values['tags'].append(payload.cuisine)

    if payload.image_presentation is None:
        presentation = (existing or {}).get('image_presentation')
        if presentation is None and (existing or {}).get('image_url'):
            presentation = _studio_row(existing)['image_presentation']
    else:
        primary = await _resolve_recipe_image(
            payload.image_presentation.primary,
            tenant=tenant,
            existing=existing,
            role='primary',
        )
        presentation = {
            'primary': primary,
            'featured': await _resolve_recipe_image(
                payload.image_presentation.featured,
                tenant=tenant,
                existing=existing,
                role='featured',
                primary=primary,
            ),
            'detail': await _resolve_recipe_image(
                payload.image_presentation.detail,
                tenant=tenant,
                existing=existing,
                role='detail',
                primary=primary,
            ),
        }
    values['image_presentation'] = presentation
    values['image_url'] = (
        presentation.get('primary', {}).get('url')
        if isinstance(presentation, dict)
        and isinstance(presentation.get('primary'), dict)
        else None
    )
    return values


@router.get('/session', response_model=StudioSession)
async def get_studio_session(membership: tuple[User, TenantContext, str] = Depends(require_studio_member)):
    _, tenant, role = membership
    return StudioSession(role=role, tenantSlug=tenant.slug)


@router.get('/brand-draft', response_model=StudioBrandDraft)
async def get_brand_draft(membership: tuple[User, TenantContext, str] = Depends(require_studio_member)):
    _, tenant, _ = membership
    draft = await supabase_service.get_studio_brand_draft(tenant.chef_id)
    if draft is None:
        draft = await supabase_service.get_published_brand_draft_seed(tenant.chef_id)
    if draft is None:
        raise HTTPException(status_code=409, detail='No published BrandConfig is available to start a draft')
    return StudioBrandDraft(config=draft['config'], version=draft['version'], updatedAt=draft.get('updated_at'))


@router.put('/brand-draft', response_model=StudioBrandDraft)
async def update_brand_draft(
    payload: StudioBrandDraftUpdate,
    membership: tuple[User, TenantContext, str] = Depends(require_studio_member),
):
    current_user, tenant, _ = membership
    if payload.config.tenant_slug != tenant.slug:
        raise HTTPException(status_code=422, detail='Draft tenantSlug must match the resolved tenant')
    ready_urls = {
        asset.get('url')
        for asset in await supabase_service.list_studio_assets(
            tenant.chef_id, 'brand')
    }
    config_urls = _brand_asset_urls(payload.config.model_dump(by_alias=True))
    # PENDING is retained for bootstrap candidates, but every remote asset in a
    # Studio draft must be a ready record owned by the resolved tenant.
    if not config_urls.issubset(ready_urls):
        raise HTTPException(status_code=422, detail='Brand assets must be validated assets from this tenant')
    saved = await supabase_service.save_studio_brand_draft(
        chef_id=tenant.chef_id, user_id=current_user.id,
        config=payload.config.model_dump(by_alias=True), expected_version=payload.expected_version,
    )
    if saved is None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail='This draft changed in another session. Reload before saving.')
    return StudioBrandDraft(config=saved['config'], version=saved['version'], updatedAt=saved.get('updated_at'))


@router.post('/brand-draft/publish', response_model=StudioPublishResult)
async def publish_brand_draft(membership: tuple[User, TenantContext, str] = Depends(require_studio_member)):
    current_user, tenant, _ = _require_admin(membership)
    draft = await supabase_service.get_studio_brand_draft(tenant.chef_id)
    if draft is None:
        raise HTTPException(status_code=409, detail='Save a draft before publishing')
    # Re-validate at the publish boundary; Pydantic also recalculates derived tokens.
    try:
        validated = StudioBrandDraftUpdate(config=draft['config'], expectedVersion=draft['version']).config
    except Exception as error:
        raise HTTPException(status_code=422, detail=f'Publish validation failed: {error}') from error
    ready_urls = {
        asset.get('url')
        for asset in await supabase_service.list_studio_assets(
            tenant.chef_id, 'brand')
    }
    if not _brand_asset_urls(validated.model_dump(by_alias=True)).issubset(ready_urls):
        raise HTTPException(status_code=422, detail='Published config references an unverified asset')
    published = await supabase_service.publish_studio_brand_draft(chef_id=tenant.chef_id, user_id=current_user.id, expected_version=draft['version'])
    if published is None:
        raise HTTPException(status_code=409, detail='Draft changed before publishing. Reload and try again.')
    return StudioPublishResult(version=published['version'], publishedAt=published['published_at'])


@router.post('/brand-config/rollback', response_model=StudioPublishResult)
async def rollback_brand_config(payload: StudioRollbackRequest, membership: tuple[User, TenantContext, str] = Depends(require_studio_member)):
    current_user, tenant, _ = _require_admin(membership)
    published = await supabase_service.rollback_studio_brand_config(chef_id=tenant.chef_id, user_id=current_user.id, source_version=payload.source_version)
    if published is None:
        raise HTTPException(status_code=404, detail='Requested config version was not found for this tenant')
    return StudioPublishResult(version=published['version'], publishedAt=published['published_at'])


@router.get('/release-status', response_model=StudioReleaseStatusView)
async def get_release_status(membership: tuple[User, TenantContext, str] = Depends(require_studio_member)):
    _, tenant, _ = membership
    snapshot = await supabase_service.get_studio_release_status(tenant.chef_id)
    jobs = [_release_response(job) for job in snapshot['jobs']]
    latest_web = next((job for job in jobs if job.kind == 'web_deploy'), None)
    latest_mobile = next((job for job in jobs if job.kind == 'mobile_build'), None)
    latest_store = next((job for job in jobs if job.kind == 'mobile_build' and job.store_release_status != 'not_submitted'), None)
    config = snapshot['config']
    return StudioReleaseStatusView(
        configPublished=None if config is None else StudioPublishResult(version=config['version'], publishedAt=config['published_at']),
        webDeployed=latest_web, mobileBuild=latest_mobile, storeRelease=latest_store, history=jobs,
    )


@router.post('/releases', response_model=StudioRelease)
async def request_release(payload: StudioReleaseRequest, membership: tuple[User, TenantContext, str] = Depends(require_studio_member)):
    current_user, tenant, _ = _require_admin(membership)
    snapshot = await supabase_service.get_studio_release_status(tenant.chef_id)
    if snapshot['config'] is None:
        raise HTTPException(status_code=409, detail='Publish a runtime config before requesting a release')
    job = await supabase_service.create_studio_release(chef_id=tenant.chef_id, user_id=current_user.id, kind=payload.kind, platform=payload.platform, config_version=snapshot['config']['version'])
    return _release_response(job)


@router.patch('/releases/{release_id}', response_model=StudioRelease)
async def update_release(release_id: str, payload: StudioReleaseUpdate, membership: tuple[User, TenantContext, str] = Depends(require_studio_member)):
    current_user, tenant, _ = _require_admin(membership)
    job = await supabase_service.update_studio_release(release_id=release_id, chef_id=tenant.chef_id, user_id=current_user.id, values=payload.model_dump(by_alias=False))
    if job is None:
        raise HTTPException(status_code=404, detail='Release job was not found for this tenant')
    return _release_response(job)


@router.get('/content')
async def list_content(membership: tuple[User, TenantContext, str] = Depends(require_studio_member)):
    _, tenant, _ = membership
    return {'content': [_studio_row(row) for row in await supabase_service.studio_content_rows(tenant.chef_id)]}


@router.get('/content/{content_id}')
async def get_content(content_id: str, membership: tuple[User, TenantContext, str] = Depends(require_studio_member)):
    _, tenant, _ = membership
    row = await supabase_service.studio_content_row(tenant.chef_id, content_id)
    if row is None:
        raise HTTPException(status_code=404, detail='Content was not found for this tenant')
    return _studio_row(row)


@router.post('/content')
async def create_content(payload: StudioContentUpsert, membership: tuple[User, TenantContext, str] = Depends(require_studio_member)):
    user, tenant, _ = membership
    values = await _content_values(payload, tenant)
    row = await supabase_service.studio_save_content(
        chef_id=tenant.chef_id,
        user_id=user.id,
        content_id=None,
        values=values,
    )
    if payload.publish_at and payload.publish_at <= datetime.now(timezone.utc):
        row = await supabase_service.studio_publish_content(chef_id=tenant.chef_id, user_id=user.id, content_id=str(row['id']))
    return _studio_row(row)


@router.put('/content/{content_id}')
async def update_content(content_id: str, payload: StudioContentUpsert, membership: tuple[User, TenantContext, str] = Depends(require_studio_member)):
    user, tenant, _ = membership
    existing = await supabase_service.studio_content_row(
        tenant.chef_id, content_id)
    if existing is None:
        raise HTTPException(status_code=404, detail='Content was not found for this tenant')
    values = await _content_values(payload, tenant, existing)
    row = await supabase_service.studio_save_content(
        chef_id=tenant.chef_id,
        user_id=user.id,
        content_id=content_id,
        values=values,
    )
    if row is None:
        raise HTTPException(status_code=404, detail='Content was not found for this tenant')
    if payload.publish_at and payload.publish_at <= datetime.now(timezone.utc):
        row = await supabase_service.studio_publish_content(chef_id=tenant.chef_id, user_id=user.id, content_id=content_id)
    return _studio_row(row)


@router.post('/content/{content_id}/publish')
async def publish_content(content_id: str, membership: tuple[User, TenantContext, str] = Depends(require_studio_member)):
    user, tenant, _ = membership
    draft = await supabase_service.studio_content_row(
        tenant.chef_id, content_id)
    if draft is None:
        raise HTTPException(status_code=404, detail='Content was not found for this tenant')
    if draft.get('content_kind', 'recipe') == 'recipe':
        missing = []
        if not draft.get('image_url'):
            missing.append('primary image')
        if not draft.get('instructions_structured'):
            missing.append('instructions')
        if not draft.get('recipe_ingredients'):
            missing.append('ingredients')
        if missing:
            raise HTTPException(
                status_code=422,
                detail=f"Recipe cannot be published without {', '.join(missing)}",
            )
    row = await supabase_service.studio_publish_content(chef_id=tenant.chef_id, user_id=user.id, content_id=content_id)
    if row is None:
        raise HTTPException(status_code=404, detail='Content was not found for this tenant')
    return _studio_row(row)


@router.get('/content/{content_id}/delete-impact')
async def content_delete_impact(content_id: str, membership: tuple[User, TenantContext, str] = Depends(require_studio_member)):
    _, tenant, _ = membership
    return await supabase_service.studio_delete_content_impact(tenant.chef_id, content_id)


@router.get('/collections')
async def list_studio_collections(membership: tuple[User, TenantContext, str] = Depends(require_studio_member)):
    _, tenant, _ = membership
    return {'collections': [_studio_row(row) for row in await supabase_service.studio_collection_rows(tenant.chef_id)]}


@router.post('/collections')
async def create_collection(payload: StudioCollectionUpsert, membership: tuple[User, TenantContext, str] = Depends(require_studio_member)):
    user, tenant, _ = membership
    row = await supabase_service.studio_save_collection(chef_id=tenant.chef_id, user_id=user.id, collection_id=None, values=payload.model_dump(by_alias=False))
    if payload.publish_at and payload.publish_at <= datetime.now(timezone.utc):
        row = await supabase_service.studio_publish_collection(chef_id=tenant.chef_id, user_id=user.id, collection_id=str(row['id']))
    return _studio_row(row)


@router.put('/collections/{collection_id}')
async def update_collection(collection_id: str, payload: StudioCollectionUpsert, membership: tuple[User, TenantContext, str] = Depends(require_studio_member)):
    user, tenant, _ = membership
    row = await supabase_service.studio_save_collection(chef_id=tenant.chef_id, user_id=user.id, collection_id=collection_id, values=payload.model_dump(by_alias=False))
    if row is None:
        raise HTTPException(status_code=404, detail='Collection was not found for this tenant')
    if payload.publish_at and payload.publish_at <= datetime.now(timezone.utc):
        row = await supabase_service.studio_publish_collection(chef_id=tenant.chef_id, user_id=user.id, collection_id=collection_id)
    return _studio_row(row)


@router.post('/collections/{collection_id}/publish')
async def publish_collection(collection_id: str, membership: tuple[User, TenantContext, str] = Depends(require_studio_member)):
    user, tenant, _ = membership
    row = await supabase_service.studio_publish_collection(chef_id=tenant.chef_id, user_id=user.id, collection_id=collection_id)
    if row is None:
        raise HTTPException(status_code=404, detail='Collection was not found for this tenant')
    return _studio_row(row)


@router.put('/merchandising')
async def save_merchandising(payload: StudioMerchandisingUpsert, membership: tuple[User, TenantContext, str] = Depends(require_studio_member)):
    user, tenant, _ = _require_admin(membership)
    return await supabase_service.studio_save_merchandising(chef_id=tenant.chef_id, user_id=user.id, values=payload.model_dump(by_alias=False))


@router.get('/assets', response_model=list[StudioAsset])
async def list_assets(membership: tuple[User, TenantContext, str] = Depends(require_studio_member)):
    _, tenant, _ = membership
    return [_asset_response(asset) for asset in await supabase_service.list_studio_assets(tenant.chef_id)]


@router.post('/assets/upload-ticket', response_model=StudioAssetUploadTicket)
async def create_asset_upload_ticket(
    payload: StudioAssetUploadRequest,
    membership: tuple[User, TenantContext, str] = Depends(require_studio_member),
):
    current_user, tenant, _ = membership
    extension = Path(payload.filename).suffix.lower()
    expected = {'.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.webp': 'image/webp'}
    if expected.get(extension) != payload.content_type:
        raise HTTPException(status_code=422, detail='Filename extension must match image content type')
    asset_id = str(uuid4())
    bucket_id = (
        _RECIPE_ASSET_BUCKET
        if payload.asset_kind == 'recipe'
        else _BRAND_ASSET_BUCKET
    )
    source_path = f'staging/{tenant.slug}/{asset_id}/source{extension}'
    await supabase_service.create_studio_asset(
        asset_id=asset_id,
        chef_id=tenant.chef_id,
        user_id=current_user.id,
        object_path=source_path,
        content_type=payload.content_type,
        size_bytes=payload.size_bytes,
        asset_kind=payload.asset_kind,
        bucket_id=bucket_id,
    )
    try:
        signed = supabase_service.get_client(use_service_key=True).storage.from_(
            bucket_id).create_signed_upload_url(source_path)
    except Exception:
        await supabase_service.reject_studio_asset(asset_id, tenant.chef_id, 'Could not create signed upload URL')
        raise HTTPException(status_code=503, detail='Asset storage is unavailable')
    return StudioAssetUploadTicket(assetId=asset_id, uploadUrl=signed['signed_url'], objectPath=source_path, expiresInSeconds=120)


@router.post('/assets/{asset_id}/finalize', response_model=StudioAsset)
async def finalize_asset_upload(
    asset_id: str, payload: StudioAssetFinalize,
    membership: tuple[User, TenantContext, str] = Depends(require_studio_member),
):
    _, tenant, _ = membership
    asset = await supabase_service.get_studio_asset(asset_id, tenant.chef_id)
    if asset is None or asset.get('state') != 'uploading':
        raise HTTPException(status_code=404, detail='Pending asset was not found')
    bucket = supabase_service.get_client(use_service_key=True).storage.from_(
        asset.get('bucket_id') or _BRAND_ASSET_BUCKET)
    try:
        raw = bucket.download(asset['source_path'])
        image = Image.open(BytesIO(raw))
        image.verify()
        image = Image.open(BytesIO(raw))
        source_format = image.format
        image = ImageOps.exif_transpose(image)
        width, height = image.size
        if not (_MIN_DIMENSION <= width <= _MAX_DIMENSION and _MIN_DIMENSION <= height <= _MAX_DIMENSION):
            raise ValueError(f'Image must be between {_MIN_DIMENSION} and {_MAX_DIMENSION}px on each side')
        if asset.get('asset_kind') == 'recipe' and (
            max(width, height) < _RECIPE_MIN_LONG_SIDE
            or min(width, height) < _RECIPE_MIN_SHORT_SIDE
        ):
            raise ValueError(
                'Recipe image must be at least 1200x800px in either orientation')
        if source_format not in {'JPEG', 'PNG', 'WEBP'}:
            raise ValueError('Unsupported image format')
        image.thumbnail((2560, 2560), Image.Resampling.LANCZOS)
        output = BytesIO()
        image.convert('RGB').save(output, format='WEBP', quality=86, method=6)
        prefix = 'recipes' if asset.get('asset_kind') == 'recipe' else 'brands'
        final_path = f'{prefix}/{tenant.slug}/{asset_id}.webp'
        bucket.upload(final_path, output.getvalue(), {'content-type': 'image/webp', 'cache-control': '31536000', 'upsert': 'false'})
        public_url = bucket.get_public_url(final_path)
        ready = await supabase_service.finalize_studio_asset(asset_id, tenant.chef_id, {
            'object_path': final_path, 'content_type': 'image/webp', 'size_bytes': output.tell(),
            'width': image.width, 'height': image.height, 'alt_text': payload.alt_text.strip(),
            'state': 'ready', 'finalized_at': datetime.now(timezone.utc).isoformat(), 'url': public_url,
        })
        bucket.remove([asset['source_path']])
        if ready is None:
            bucket.remove([final_path])
            raise HTTPException(status_code=409, detail='Asset upload changed; retry')
        return _asset_response(ready)
    except HTTPException:
        raise
    except (UnidentifiedImageError, ValueError, Image.DecompressionBombError) as error:
        await supabase_service.reject_studio_asset(asset_id, tenant.chef_id, str(error))
        try:
            bucket.remove([asset['source_path']])
        except Exception:
            pass
        raise HTTPException(status_code=422, detail=f'Asset rejected: {error}')
    except Exception:
        raise HTTPException(status_code=503, detail='Asset validation is temporarily unavailable')


def _brand_asset_urls(config: dict) -> set[str]:
    brand = config['brand']
    urls = {value for value in (brand.get('avatar'), brand.get('logo')) if isinstance(value, str) and value.startswith(('http://', 'https://'))}
    urls.update(photo['url'] for photo in brand.get('heroPhotos', []) if isinstance(photo.get('url'), str) and photo['url'].startswith(('http://', 'https://')))
    return urls


def _asset_response(asset: dict) -> StudioAsset:
    return StudioAsset(
        id=str(asset['id']),
        url=asset.get('url'),
        altText=asset.get('alt_text') or '',
        width=asset.get('width'),
        height=asset.get('height'),
        state=asset['state'],
        assetKind=asset.get('asset_kind', 'brand'),
    )


def _release_response(job: dict) -> StudioRelease:
    return StudioRelease(id=str(job['id']), kind=job['kind'], status=job['status'], platform=job.get('platform'), configVersion=job['config_version'], storeReleaseStatus=job['store_release_status'], failureReason=job.get('failure_reason'), requestedAt=job['requested_at'], updatedAt=job['updated_at'])
