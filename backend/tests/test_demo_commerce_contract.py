import asyncio
from pathlib import Path

import pytest
from fastapi import HTTPException

from app.api.v1.endpoints import commerce
from app.api.v1.endpoints.auth import User
from app.core.settings import settings
from app.core.tenant import TenantContext
from app.services.database import SupabaseService
from app.services import commerce_service


def _tenant(slug='tenant-a'):
    return TenantContext(chef_id='tenant-a', slug=slug)


def test_demo_mode_fails_closed_and_allowlist_is_server_only(monkeypatch):
    monkeypatch.setattr(settings, 'commerce_mode', 'unexpected')
    monkeypatch.setattr(settings, 'demo_commerce_allowed_emails', 'buyer@example.com')
    assert settings.normalized_commerce_mode == 'disabled'
    assert not commerce_service.demo_purchase_enabled_for('buyer@example.com')
    monkeypatch.setattr(settings, 'commerce_mode', 'demo')
    assert commerce_service.demo_purchase_enabled_for('BUYER@example.com')
    assert not commerce_service.demo_purchase_enabled_for('other@example.com')


def test_catalogue_is_authenticated_tenant_scoped_and_does_not_return_allowlist(monkeypatch):
    monkeypatch.setattr(settings, 'commerce_mode', 'demo')
    monkeypatch.setattr(settings, 'demo_commerce_allowed_emails', 'buyer@example.com')

    async def offers(chef_id):
        assert chef_id == 'tenant-a'
        return [{'offer_key': 'monthly', 'title': 'Monthly', 'amount_minor': 999, 'currency': 'EUR',
                 'billing_period': 'month', 'product': {'kind': 'subscription', 'product_content': []}}]

    monkeypatch.setattr(commerce.supabase_service, 'get_active_web_offers', offers)
    result = asyncio.run(commerce.catalogue(User(id='user-a', email='buyer@example.com'), _tenant()))
    assert result['demoPurchaseAvailable'] is True
    assert result['offers'][0]['accessScope'] == 'tenant'
    assert 'allowed' not in str(result).lower().replace('available', '')


def test_demo_purchase_requires_mode_allowlist_and_idempotency(monkeypatch):
    monkeypatch.setattr(settings, 'commerce_mode', 'demo')
    monkeypatch.setattr(settings, 'demo_commerce_allowed_emails', 'buyer@example.com')
    calls = []

    async def purchase(**kwargs):
        calls.append(kwargs)
        return {'accepted': True, 'entitlementId': 'ent-1', 'scopeType': 'tenant'}

    monkeypatch.setattr(commerce.supabase_service, 'issue_demo_purchase', purchase)
    body = commerce.DemoPurchaseRequest(offerKey='monthly')
    result = asyncio.run(commerce.demo_purchase(body, 'retry-1', User(id='user-a', email='buyer@example.com'), _tenant()))
    assert result['entitlementId'] == 'ent-1'
    assert calls == [{'user_id': 'user-a', 'chef_id': 'tenant-a', 'offer_key': 'monthly', 'idempotency_key': 'retry-1'}]
    with pytest.raises(HTTPException) as missing:
        asyncio.run(commerce.demo_purchase(body, None, User(id='user-a', email='buyer@example.com'), _tenant()))
    assert missing.value.status_code == 400
    with pytest.raises(HTTPException) as denied:
        asyncio.run(commerce.demo_purchase(body, 'retry-2', User(id='user-a', email='other@example.com'), _tenant()))
    assert denied.value.status_code == 403


def test_demo_purchase_rpc_accepts_jsonb_object_response(monkeypatch):
    class Result:
        data = {'accepted': True, 'entitlementId': 'ent-1', 'scopeType': 'tenant'}

    class Rpc:
        def execute(self):
            return Result()

    class Client:
        def rpc(self, name, params):
            assert name == 'issue_demo_purchase'
            assert params['p_offer_key'] == 'demo-monthly'
            return Rpc()

    service = SupabaseService.__new__(SupabaseService)
    monkeypatch.setattr(service, 'get_client', lambda use_service_key: Client())

    result = asyncio.run(service.issue_demo_purchase(
        user_id='user-a', chef_id='tenant-a', offer_key='demo-monthly',
        idempotency_key='retry-1',
    ))

    assert result == Result.data


def test_demo_migration_has_atomic_server_owned_contract_and_seed():
    sql = (Path(__file__).resolve().parents[1] / 'migrations/2026_07_16_demo_commerce.sql').read_text()
    assert "source IN ('migration', 'store', 'admin', 'demo')" in sql
    assert 'CREATE OR REPLACE FUNCTION public.issue_demo_purchase' in sql
    assert "'demo', v_event_key" in sql
    assert "now() + interval '30 days'" in sql
    assert 'REVOKE ALL ON FUNCTION public.issue_demo_purchase' in sql
    assert 'TO service_role' in sql
    assert "'demo-monthly'" in sql and "'demo-annual'" in sql
    assert "'demo-premium-collection'" in sql
    assert 'p_email' not in sql and 'p_price' not in sql and 'p_collection_id' not in sql
