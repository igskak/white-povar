import asyncio
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.api.v1.endpoints import commerce
from app.core.tenant import TenantContext
from app.services import commerce_service


def _event(**overrides):
    event = {
        'id': 'event-1', 'type': 'INITIAL_PURCHASE',
        'app_user_id': str(uuid4()), 'product_id': 'com.example.monthly',
        'store': 'APP_STORE', 'event_timestamp_ms': 1_750_000_000_000,
    }
    event.update(overrides)
    return {'event': event}


def test_webhook_requires_configured_constant_time_authorization(monkeypatch):
    monkeypatch.setattr(commerce_service.settings, 'revenuecat_webhook_authorization', 'Bearer test-secret')
    commerce_service.verify_revenuecat_authorization('Bearer test-secret')
    with pytest.raises(HTTPException) as error:
        commerce_service.verify_revenuecat_authorization('Bearer wrong')
    assert error.value.status_code == 401


def test_webhook_rejects_client_shaped_or_incomplete_event():
    with pytest.raises(HTTPException) as error:
        commerce_service.revenuecat_event({'event': {'id': 'only-id'}})
    assert error.value.status_code == 400


def test_webhook_delegates_idempotency_and_ordering_to_server_rpc(monkeypatch):
    received = []

    async def process(event):
        received.append(event)
        return {'accepted': True, 'duplicate': len(received) > 1}

    monkeypatch.setattr(commerce_service.supabase_service, 'process_revenuecat_event', process)
    payload = _event()
    first = asyncio.run(commerce_service.process_revenuecat_webhook(payload))
    duplicate = asyncio.run(commerce_service.process_revenuecat_webhook(payload))
    assert first == {'accepted': True, 'duplicate': False}
    assert duplicate == {'accepted': True, 'duplicate': True}
    assert received[0]['app_user_id'] == received[1]['app_user_id']


def test_store_catalog_is_resolved_from_tenant_not_client_product_data(monkeypatch):
    tenant = TenantContext(chef_id=str(uuid4()), slug='tenant-a')

    async def products(chef_id, store):
        assert (chef_id, store) == (tenant.chef_id, 'app_store')
        return [{'store_product_id': 'com.example.monthly', 'product': {'product_key': 'monthly', 'kind': 'subscription'}}]

    monkeypatch.setattr(commerce.supabase_service, 'get_active_store_products', products)
    result = asyncio.run(commerce.store_products('app_store', tenant))
    assert result == {'products': [{'storeProductId': 'com.example.monthly', 'productKey': 'monthly', 'kind': 'subscription'}]}


def test_migration_has_atomic_event_ledger_and_newer_event_guard():
    path = commerce.__file__.replace('app/api/v1/endpoints/commerce.py', 'migrations/2026_07_15_mobile_store_webhooks.sql')
    with open(path, encoding='utf-8') as source:
        sql = source.read()
    assert 'process_revenuecat_event' in sql
    assert 'ON CONFLICT (provider, event_key) DO NOTHING' in sql
    assert 'entitlement.updated_at > rc_occurred_at' in sql
    assert 'store_product_mappings_enforce_tenant' in sql
