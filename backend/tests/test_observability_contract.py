import asyncio

from app.api.v1.endpoints import analytics
from app.api.v1.endpoints.auth import User
from app.core.tenant import TenantContext
from app.schemas.analytics import AnalyticsEventInput


def _user():
    return User(id='user-a', email='private@example.com')


def _tenant():
    return TenantContext(slug='tenant-a', chef_id='chef-a')


def test_event_is_scoped_to_resolved_tenant_and_has_no_freeform_properties(monkeypatch):
    calls = []

    async def record(*args):
        calls.append(args)

    monkeypatch.setattr(analytics.supabase_service, 'record_analytics_event', record)
    asyncio.run(analytics.record_event(
        AnalyticsEventInput(name='search_completed', outcome='empty'), _user(), _tenant(),
    ))
    assert calls == [('user-a', 'chef-a', 'search_completed', 'empty', None)]


def test_consent_is_tenant_scoped(monkeypatch):
    calls = []

    async def set_consent(*args):
        calls.append(args)

    monkeypatch.setattr(analytics.supabase_service, 'set_analytics_consent', set_consent)
    saved = asyncio.run(analytics.set_consent(
        analytics.AnalyticsConsent(analytics_consent=True), _user(), _tenant(),
    ))
    assert saved.analytics_consent is True
    assert calls == [('user-a', 'chef-a', True)]


def test_migration_forbids_sensitive_event_payloads_and_cascades_deletion():
    sql = open('migrations/2026_07_16_observability.sql', encoding='utf-8').read()
    assert 'ON DELETE CASCADE' in sql
    assert 'properties JSONB' not in sql
    assert 'analytics_tenant_daily_funnel' in sql
    assert 'ENABLE ROW LEVEL SECURITY' in sql
