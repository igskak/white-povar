"""Internal-only Creator Studio drafts and tenant-bound image assets."""

from io import BytesIO
from pathlib import Path
from uuid import uuid4
from datetime import datetime, timezone

from PIL import Image, UnidentifiedImageError

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
_ASSET_BUCKET = 'studio-brand-assets'
_MAX_DIMENSION = 6000
_MIN_DIMENSION = 320


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
    return {**row, 'id': str(row['id']), 'chef_id': str(row['chef_id'])}


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
    ready_urls = {asset.get('url') for asset in await supabase_service.list_studio_assets(tenant.chef_id)}
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
    ready_urls = {asset.get('url') for asset in await supabase_service.list_studio_assets(tenant.chef_id)}
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


@router.post('/content')
async def create_content(payload: StudioContentUpsert, membership: tuple[User, TenantContext, str] = Depends(require_studio_member)):
    user, tenant, _ = membership
    row = await supabase_service.studio_save_content(chef_id=tenant.chef_id, user_id=user.id, content_id=None, values=payload.model_dump(by_alias=False))
    if payload.publish_at and payload.publish_at <= datetime.now(timezone.utc):
        row = await supabase_service.studio_publish_content(chef_id=tenant.chef_id, user_id=user.id, content_id=str(row['id']))
    return _studio_row(row)


@router.put('/content/{content_id}')
async def update_content(content_id: str, payload: StudioContentUpsert, membership: tuple[User, TenantContext, str] = Depends(require_studio_member)):
    user, tenant, _ = membership
    row = await supabase_service.studio_save_content(chef_id=tenant.chef_id, user_id=user.id, content_id=content_id, values=payload.model_dump(by_alias=False))
    if row is None:
        raise HTTPException(status_code=404, detail='Content was not found for this tenant')
    if payload.publish_at and payload.publish_at <= datetime.now(timezone.utc):
        row = await supabase_service.studio_publish_content(chef_id=tenant.chef_id, user_id=user.id, content_id=content_id)
    return _studio_row(row)


@router.post('/content/{content_id}/publish')
async def publish_content(content_id: str, membership: tuple[User, TenantContext, str] = Depends(require_studio_member)):
    user, tenant, _ = membership
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
    source_path = f'staging/{tenant.slug}/{asset_id}/source{extension}'
    await supabase_service.create_studio_asset(asset_id=asset_id, chef_id=tenant.chef_id, user_id=current_user.id, object_path=source_path, content_type=payload.content_type, size_bytes=payload.size_bytes)
    try:
        signed = supabase_service.get_client(use_service_key=True).storage.from_(_ASSET_BUCKET).create_signed_upload_url(source_path)
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
    bucket = supabase_service.get_client(use_service_key=True).storage.from_(_ASSET_BUCKET)
    try:
        raw = bucket.download(asset['source_path'])
        image = Image.open(BytesIO(raw))
        image.verify()
        image = Image.open(BytesIO(raw))
        width, height = image.size
        if not (_MIN_DIMENSION <= width <= _MAX_DIMENSION and _MIN_DIMENSION <= height <= _MAX_DIMENSION):
            raise ValueError(f'Image must be between {_MIN_DIMENSION} and {_MAX_DIMENSION}px on each side')
        if image.format not in {'JPEG', 'PNG', 'WEBP'}:
            raise ValueError('Unsupported image format')
        image.thumbnail((2560, 2560), Image.Resampling.LANCZOS)
        output = BytesIO()
        image.convert('RGB').save(output, format='WEBP', quality=86, method=6)
        final_path = f'brands/{tenant.slug}/{asset_id}.webp'
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
    return StudioAsset(id=str(asset['id']), url=asset.get('url'), altText=asset.get('alt_text') or '', width=asset.get('width'), height=asset.get('height'), state=asset['state'])


def _release_response(job: dict) -> StudioRelease:
    return StudioRelease(id=str(job['id']), kind=job['kind'], status=job['status'], platform=job.get('platform'), configVersion=job['config_version'], storeReleaseStatus=job['store_release_status'], failureReason=job.get('failure_reason'), requestedAt=job['requested_at'], updatedAt=job['updated_at'])
