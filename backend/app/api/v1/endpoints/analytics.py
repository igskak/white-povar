"""Consent-gated, tenant-safe analytics ingestion."""
from fastapi import APIRouter, Depends, status

from app.api.v1.endpoints.auth import User, verify_firebase_token
from app.core.tenant import TenantContext, require_tenant_context
from app.schemas.analytics import AnalyticsConsent, AnalyticsEventInput
from app.services.database import supabase_service

router = APIRouter()


@router.get('/me/consent', response_model=AnalyticsConsent)
async def get_consent(
    current_user: User = Depends(verify_firebase_token),
    tenant: TenantContext = Depends(require_tenant_context),
):
    return AnalyticsConsent(analytics_consent=await supabase_service.analytics_consent(
        current_user.id, tenant.chef_id,
    ))


@router.put('/me/consent', response_model=AnalyticsConsent)
async def set_consent(
    consent: AnalyticsConsent,
    current_user: User = Depends(verify_firebase_token),
    tenant: TenantContext = Depends(require_tenant_context),
):
    await supabase_service.set_analytics_consent(
        current_user.id, tenant.chef_id, consent.analytics_consent,
    )
    return consent


@router.post('/events', status_code=status.HTTP_204_NO_CONTENT)
async def record_event(
    event: AnalyticsEventInput,
    current_user: User = Depends(verify_firebase_token),
    tenant: TenantContext = Depends(require_tenant_context),
):
    # Consent is checked again in the database service.  Never trust a client
    # setting to decide whether an event may be retained.
    await supabase_service.record_analytics_event(
        current_user.id, tenant.chef_id, event.name, event.outcome,
        event.client_version,
    )
