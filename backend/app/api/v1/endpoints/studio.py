"""Internal-only Creator Studio drafts."""

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.v1.endpoints.auth import User, verify_firebase_token
from app.core.tenant import TenantContext, require_tenant_context
from app.schemas.studio import StudioBrandDraft, StudioBrandDraftUpdate, StudioSession
from app.services.database import supabase_service

router = APIRouter()


async def require_studio_member(
    current_user: User = Depends(verify_firebase_token),
    tenant: TenantContext = Depends(require_tenant_context),
) -> tuple[User, TenantContext, str]:
    role = await supabase_service.get_studio_role(current_user.id, tenant.chef_id)
    if role not in {'editor', 'admin'}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail='Internal Studio access is required')
    return current_user, tenant, role


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
    saved = await supabase_service.save_studio_brand_draft(
        chef_id=tenant.chef_id, user_id=current_user.id,
        config=payload.config.model_dump(by_alias=True), expected_version=payload.expected_version,
    )
    if saved is None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail='This draft changed in another session. Reload before saving.')
    return StudioBrandDraft(config=saved['config'], version=saved['version'], updatedAt=saved.get('updated_at'))
