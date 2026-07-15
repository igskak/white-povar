import asyncio

from app.api.v1.endpoints import commerce
from app.api.v1.endpoints.auth import User
from app.core.tenant import TenantContext


def _tenant():
    return TenantContext(chef_id='tenant-a', slug='tenant-a')


def test_entitlement_status_is_tenant_scoped_and_server_authoritative(monkeypatch):
    async def entitlements(user_id, chef_id):
        assert (user_id, chef_id) == ('user-a', 'tenant-a')
        return [{
            'scope_type': 'tenant', 'status': 'active', 'expires_at': None,
            'updated_at': '2026-07-15T12:00:00+00:00',
            'product': {'kind': 'subscription'},
        }]

    monkeypatch.setattr(commerce.supabase_service, 'get_commerce_entitlements', entitlements)
    result = asyncio.run(commerce.entitlement_status(
        User(id='user-a', email='buyer@example.com'), _tenant(),
    ))
    assert result == {'hasAccess': True, 'status': 'active', 'expiresAt': None}


def test_entitlement_status_does_not_grant_expired_or_one_off_subscription_scope(monkeypatch):
    async def entitlements(*_args):
        return [
            {'scope_type': 'collection', 'status': 'active', 'product': {'kind': 'one_off'}},
            {'scope_type': 'tenant', 'status': 'expired', 'product': {'kind': 'subscription'}},
        ]

    monkeypatch.setattr(commerce.supabase_service, 'get_commerce_entitlements', entitlements)
    result = asyncio.run(commerce.entitlement_status(
        User(id='user-a', email='buyer@example.com'), _tenant(),
    ))
    assert result['hasAccess'] is False
    assert result['status'] == 'expired'
