import asyncio

from app.api.v1.endpoints import lifecycle
from app.api.v1.endpoints.auth import User
from app.core.tenant import TenantContext
from app.schemas.lifecycle import NotificationPreferences


def _user():
    return User(id='user-a', email='a@example.com')


def _tenant():
    return TenantContext(slug='tenant-a', chef_id='chef-a')


def test_marketing_content_is_disabled_without_explicit_consent(monkeypatch):
    calls = []

    async def upsert(*args):
        calls.append(args)

    monkeypatch.setattr(lifecycle.supabase_service, 'upsert_notification_preferences', upsert)
    saved = asyncio.run(lifecycle.save_preferences(
        NotificationPreferences(marketing_consent=False, new_content=True), _user(), _tenant(),
    ))
    assert saved.new_content is False
    assert calls[0][0:2] == ('user-a', 'chef-a')
    assert calls[0][2]['new_content'] is False


def test_device_binding_and_revocation_are_resolved_to_tenant(monkeypatch):
    calls = []

    async def register(*args):
        calls.append(('register', args))

    async def delete(*args):
        calls.append(('delete', args))

    monkeypatch.setattr(lifecycle.supabase_service, 'upsert_push_device', register)
    monkeypatch.setattr(lifecycle.supabase_service, 'delete_push_devices', delete)
    device = lifecycle.PushDeviceRegistration(token='x' * 32, platform='ios')
    asyncio.run(lifecycle.register_device(device, _user(), _tenant()))
    asyncio.run(lifecycle.unregister_devices(_user(), _tenant()))
    assert calls == [
        ('register', ('user-a', 'chef-a', 'x' * 32, 'ios')),
        ('delete', ('user-a', 'chef-a')),
    ]


def test_migration_has_cascades_tenant_scope_and_frequency_cap():
    sql = open('migrations/2026_07_16_lifecycle_notifications.sql', encoding='utf-8').read()
    assert sql.count('ON DELETE CASCADE') >= 4
    assert 'lifecycle_marketing_requires_consent' in sql
    assert 'lifecycle_frequency_cap_idx' in sql
    assert 'ENABLE ROW LEVEL SECURITY' in sql
