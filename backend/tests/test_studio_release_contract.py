import asyncio
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.api.v1.endpoints.auth import User
from app.api.v1.endpoints.studio import (
    get_release_status, publish_brand_draft, request_release, update_release,
)
from app.core.tenant import TenantContext
from app.schemas.studio import StudioReleaseRequest, StudioReleaseUpdate
from app.services.database import supabase_service
from tests.test_studio_draft_contract import _config


def _membership(role='admin'):
    return User(id=str(uuid4()), email='admin@example.test'), TenantContext('chef-1', 'ohorodnik-oleksandr'), role


def test_publish_revalidates_draft_and_records_immutable_result(monkeypatch):
    async def draft(*_): return {'config': _config(), 'version': 4}
    async def assets(*_): return []
    async def publish(**kwargs):
        assert kwargs['expected_version'] == 4
        return {'version': 5, 'published_at': '2026-07-15T12:00:00+00:00'}
    monkeypatch.setattr(supabase_service, 'get_studio_brand_draft', draft)
    monkeypatch.setattr(supabase_service, 'list_studio_assets', assets)
    monkeypatch.setattr(supabase_service, 'publish_studio_brand_draft', publish)
    result = asyncio.run(publish_brand_draft(_membership()))
    assert result.version == 5


def test_release_request_is_queued_not_a_false_deploy(monkeypatch):
    async def snapshot(*_): return {'config': {'version': 7, 'published_at': '2026-07-15T12:00:00+00:00'}, 'jobs': []}
    async def create(**kwargs):
        assert kwargs['config_version'] == 7
        return {'id': str(uuid4()), 'kind': kwargs['kind'], 'platform': kwargs['platform'], 'config_version': 7, 'status': 'queued', 'store_release_status': 'not_submitted', 'failure_reason': None, 'requested_at': '2026-07-15T12:00:00+00:00', 'updated_at': '2026-07-15T12:00:00+00:00'}
    monkeypatch.setattr(supabase_service, 'get_studio_release_status', snapshot)
    monkeypatch.setattr(supabase_service, 'create_studio_release', create)
    job = asyncio.run(request_release(StudioReleaseRequest(kind='mobile_build', platform='ios'), _membership()))
    assert job.status == 'queued'
    assert job.store_release_status == 'not_submitted'


def test_only_admin_can_request_or_change_releases():
    with pytest.raises(HTTPException) as error:
        asyncio.run(request_release(StudioReleaseRequest(kind='web_deploy'), _membership('editor')))
    assert error.value.status_code == 403
    with pytest.raises(HTTPException) as error:
        asyncio.run(update_release(str(uuid4()), StudioReleaseUpdate(status='failed', failureReason='build failed'), _membership('editor')))
    assert error.value.status_code == 403


def test_status_keeps_web_mobile_and_store_distinct(monkeypatch):
    async def snapshot(*_):
        def job(kind, status, store):
            return {'id': str(uuid4()), 'kind': kind, 'platform': 'ios' if kind == 'mobile_build' else None, 'config_version': 3, 'status': status, 'store_release_status': store, 'failure_reason': None, 'requested_at': '2026-07-15T12:00:00+00:00', 'updated_at': '2026-07-15T12:00:00+00:00'}
        return {'config': {'version': 3, 'published_at': '2026-07-15T12:00:00+00:00'}, 'jobs': [job('mobile_build', 'queued', 'pending'), job('web_deploy', 'succeeded', 'not_submitted')]}
    monkeypatch.setattr(supabase_service, 'get_studio_release_status', snapshot)
    result = asyncio.run(get_release_status(_membership()))
    assert result.config_published.version == 3
    assert result.web_deployed.status == 'succeeded'
    assert result.mobile_build.status == 'queued'
    assert result.store_release.store_release_status == 'pending'
