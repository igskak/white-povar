"""Tenant-safe mobile store catalogue and trusted billing webhooks."""
from typing import Literal

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from pydantic import BaseModel, Field

from app.api.v1.endpoints.auth import User, verify_firebase_token
from app.core.tenant import TenantContext, require_tenant_context
from app.services.commerce_service import (
    demo_purchase_enabled_for,
    process_revenuecat_webhook,
    verify_revenuecat_authorization,
)
from app.core.settings import settings
from app.services.database import supabase_service
from app.services.subscription_service import SubscriptionService

router = APIRouter()


class DemoPurchaseRequest(BaseModel):
    offer_key: str = Field(min_length=1, max_length=120, alias='offerKey')

    model_config = {'populate_by_name': True}


def _web_offer(row):
    product = row.get('product') or {}
    content = product.get('product_content') or []
    collection_ids = [item['collection_id'] for item in content if item.get('collection_id')]
    return {
        'offerKey': row['offer_key'], 'title': row.get('title'),
        'description': row.get('description'), 'amountMinor': row.get('amount_minor'),
        'currency': row.get('currency'), 'billingPeriod': row.get('billing_period'),
        'badge': row.get('badge'), 'trialDays': row.get('trial_days'),
        'productKind': product.get('kind'),
        'accessScope': 'tenant' if product.get('kind') == 'subscription' else 'collection',
        'collectionIds': collection_ids,
    }


@router.get('/catalogue')
async def catalogue(
    current_user: User = Depends(verify_firebase_token),
    tenant: TenantContext = Depends(require_tenant_context),
):
    rows = await supabase_service.get_active_web_offers(tenant.chef_id)
    return {
        'offers': [_web_offer(row) for row in rows],
        'commerceMode': settings.normalized_commerce_mode,
        # This indicates eligibility only; the allowlist itself remains server-only.
        'demoPurchaseAvailable': demo_purchase_enabled_for(current_user.email),
    }


@router.post('/demo-purchases')
async def demo_purchase(
    body: DemoPurchaseRequest,
    idempotency_key: str | None = Header(None, alias='Idempotency-Key'),
    current_user: User = Depends(verify_firebase_token),
    tenant: TenantContext = Depends(require_tenant_context),
):
    if settings.normalized_commerce_mode != 'demo':
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                            detail='Demo commerce is unavailable')
    if not demo_purchase_enabled_for(current_user.email):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,
                            detail='Demo commerce is unavailable')
    if not idempotency_key or len(idempotency_key) > 200:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST,
                            detail='Idempotency-Key is required')
    result = await supabase_service.issue_demo_purchase(
        user_id=current_user.id, chef_id=tenant.chef_id,
        offer_key=body.offer_key, idempotency_key=idempotency_key,
    )
    if not result.get('accepted'):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='Offer not found')
    return result


@router.get('/store-products')
async def store_products(
    store: Literal['app_store', 'play_store'],
    tenant: TenantContext = Depends(require_tenant_context),
):
    """Identifiers only; StoreKit/Play Billing remains the price authority."""
    rows = await supabase_service.get_active_store_products(tenant.chef_id, store)
    return {'products': [
        {
            'storeProductId': row['store_product_id'],
            'productKey': (row.get('product') or {}).get('product_key'),
            'kind': (row.get('product') or {}).get('kind'),
        }
        for row in rows
    ]}


@router.get('/entitlement-status')
async def entitlement_status(
    current_user: User = Depends(verify_firebase_token),
    tenant: TenantContext = Depends(require_tenant_context),
):
    """Return the minimum tenant-scoped server entitlement read model.

    A completed store sheet is intentionally not represented here. Only the
    webhook-issued commerce entitlement can make ``hasAccess`` true.
    """
    rows = await supabase_service.get_commerce_entitlements(
        current_user.id, tenant.chef_id,
    )
    subscriptions = [
        row for row in rows
        if (row.get('product') or {}).get('kind') == 'subscription'
        and row.get('scope_type') == 'tenant'
    ]
    subscriptions.sort(key=lambda row: row.get('updated_at') or '', reverse=True)
    row = subscriptions[0] if subscriptions else None
    has_access = bool(row and SubscriptionService._is_accessible_entitlement(row))
    return {
        'hasAccess': has_access,
        'status': row.get('status') if row else None,
        'expiresAt': row.get('expires_at') if row else None,
    }


@router.post('/webhooks/revenuecat', status_code=200)
async def revenuecat_webhook(
    request: Request,
    authorization: str | None = Header(None),
):
    verify_revenuecat_authorization(authorization)
    return await process_revenuecat_webhook(await request.json())
