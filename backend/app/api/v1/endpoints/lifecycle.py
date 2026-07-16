"""Lifecycle preferences and push bindings.

Delivery is intentionally performed by an authenticated external worker.  The
API stores only a tenant-bound device token and delivery policy; it never
pretends that a provider accepted a notification.
"""
from fastapi import APIRouter, Depends, status

from app.api.v1.endpoints.auth import User, verify_firebase_token
from app.core.tenant import TenantContext, require_tenant_context
from app.schemas.lifecycle import NotificationPreferences, PushDeviceRegistration
from app.services.database import supabase_service

router = APIRouter()


@router.get('/me/preferences', response_model=NotificationPreferences)
async def get_preferences(
    current_user: User = Depends(verify_firebase_token),
    tenant: TenantContext = Depends(require_tenant_context),
):
    saved = await supabase_service.get_notification_preferences(current_user.id, tenant.chef_id)
    return NotificationPreferences(**(saved or {}))


@router.put('/me/preferences', response_model=NotificationPreferences)
async def save_preferences(
    preferences: NotificationPreferences,
    current_user: User = Depends(verify_firebase_token),
    tenant: TenantContext = Depends(require_tenant_context),
):
    # Content campaigns are marketing and cannot be enabled without consent.
    if not preferences.marketing_consent:
        preferences.new_content = False
    await supabase_service.upsert_notification_preferences(
        current_user.id, tenant.chef_id, preferences.model_dump(mode='json'),
    )
    return preferences


@router.put('/me/devices', status_code=status.HTTP_204_NO_CONTENT)
async def register_device(
    device: PushDeviceRegistration,
    current_user: User = Depends(verify_firebase_token),
    tenant: TenantContext = Depends(require_tenant_context),
):
    await supabase_service.upsert_push_device(
        current_user.id, tenant.chef_id, device.token, device.platform,
    )


@router.delete('/me/devices', status_code=status.HTTP_204_NO_CONTENT)
async def unregister_devices(
    current_user: User = Depends(verify_firebase_token),
    tenant: TenantContext = Depends(require_tenant_context),
):
    await supabase_service.delete_push_devices(current_user.id, tenant.chef_id)
