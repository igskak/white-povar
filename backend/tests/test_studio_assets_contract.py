import asyncio
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.api.v1.endpoints.auth import User
from app.api.v1.endpoints.studio import create_asset_upload_ticket, update_brand_draft
from app.core.tenant import TenantContext
from app.schemas.studio import StudioAssetUploadRequest, StudioBrandDraftUpdate
from app.services.database import supabase_service
from tests.test_studio_draft_contract import _config


def _membership():
    return User(id=str(uuid4()), email='editor@example.test'), TenantContext('chef-1', 'ohorodnik-oleksandr'), 'editor'


def test_upload_ticket_uses_server_owned_tenant_prefix(monkeypatch):
    captured = {}
    async def created(**kwargs): captured.update(kwargs)
    class Bucket:
        def create_signed_upload_url(self, path):
            captured['signed_path'] = path
            return {'signed_url': 'https://storage.test/signed?token=one'}
    class Storage:
        def from_(self, _): return Bucket()
    class Client: storage = Storage()
    monkeypatch.setattr(supabase_service, 'create_studio_asset', created)
    monkeypatch.setattr(supabase_service, 'get_client', lambda **_: Client())
    ticket = asyncio.run(create_asset_upload_ticket(StudioAssetUploadRequest(filename='cover.jpg', contentType='image/jpeg', sizeBytes=400), _membership()))
    assert ticket.upload_url.startswith('https://storage.test/')
    assert captured['object_path'] == captured['signed_path']
    assert captured['object_path'].startswith('staging/ohorodnik-oleksandr/')


def test_draft_rejects_ready_asset_url_from_another_tenant(monkeypatch):
    async def foreign_assets(*_):
        return [{'url': 'https://storage.test/brands/another/asset.webp'}]
    monkeypatch.setattr(supabase_service, 'list_studio_assets', foreign_assets)
    config = _config()
    config['brand']['avatar'] = 'https://storage.test/brands/ohorodnik-oleksandr/forged.webp'
    with pytest.raises(HTTPException) as error:
        asyncio.run(update_brand_draft(StudioBrandDraftUpdate(config=config, expectedVersion=1), _membership()))
    assert error.value.status_code == 422
