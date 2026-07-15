"""Tenant-safe mobile store catalogue and trusted billing webhooks."""
from typing import Literal

from fastapi import APIRouter, Depends, Header, Request

from app.api.v1.endpoints.auth import User, verify_firebase_token
from app.core.tenant import TenantContext, require_tenant_context
from app.services.commerce_service import (
    process_revenuecat_webhook,
    verify_revenuecat_authorization,
)
from app.services.database import supabase_service
from app.services.subscription_service import SubscriptionService

router = APIRouter()


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
