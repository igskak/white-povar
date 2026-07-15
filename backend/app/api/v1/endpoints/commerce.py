"""Tenant-safe mobile store catalogue and trusted billing webhooks."""
from typing import Literal

from fastapi import APIRouter, Depends, Header, Request

from app.core.tenant import TenantContext, require_tenant_context
from app.services.commerce_service import (
    process_revenuecat_webhook,
    verify_revenuecat_authorization,
)
from app.services.database import supabase_service

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


@router.post('/webhooks/revenuecat', status_code=200)
async def revenuecat_webhook(
    request: Request,
    authorization: str | None = Header(None),
):
    verify_revenuecat_authorization(authorization)
    return await process_revenuecat_webhook(await request.json())
