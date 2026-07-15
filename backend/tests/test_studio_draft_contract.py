import asyncio
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.api.v1.endpoints.studio import get_brand_draft, require_studio_member, update_brand_draft
from app.api.v1.endpoints.auth import User
from app.core.tenant import TenantContext
from app.schemas.studio import StudioBrandDraftUpdate
from app.services.database import supabase_service


def _config(slug='ohorodnik-oleksandr'):
    return {
        'schemaVersion': 1, 'tenantSlug': slug, 'locale': 'uk',
        'brand': {
            'name': 'Огороднік Олександр', 'creatorName': 'Олександр',
            'avatar': 'PENDING:/brands/ohorodnik-oleksandr/avatar-512.png', 'accent': '#5D7183',
            'font': 'grotesque',
            'voice': {'greeting': 'Ой, друзі, ну це щось...', 'loginTitle': 'Готуйте з Олександром', 'paywallTitle': 'Колекції Олександра', 'courseName': 'Майстерня Олександра'},
            'courseTag': 'maisternia-oleksandra', 'heroPhotos': [], 'logo': None,
        },
    }


def test_non_member_is_rejected_before_any_studio_draft_access(monkeypatch):
    async def no_role(*_):
        return None
    monkeypatch.setattr(supabase_service, 'get_studio_role', no_role)
    with pytest.raises(HTTPException) as error:
        asyncio.run(require_studio_member(User(id=str(uuid4()), email='outside@example.test'), TenantContext('chef-1', 'ohorodnik-oleksandr')))
    assert error.value.status_code == 403


def test_draft_seed_and_conflict_are_explicit(monkeypatch):
    membership = (User(id=str(uuid4()), email='editor@example.test'), TenantContext('chef-1', 'ohorodnik-oleksandr'), 'editor')
    seed = {'config': _config(), 'version': 3, 'updated_at': None}
    async def no_draft(*_):
        return None
    async def published_seed(*_):
        return seed
    monkeypatch.setattr(supabase_service, 'get_studio_brand_draft', no_draft)
    monkeypatch.setattr(supabase_service, 'get_published_brand_draft_seed', published_seed)
    loaded = asyncio.run(get_brand_draft(membership))
    assert loaded.version == 3

    async def conflict(**_):
        return None
    monkeypatch.setattr(supabase_service, 'save_studio_brand_draft', conflict)
    with pytest.raises(HTTPException) as error:
        asyncio.run(update_brand_draft(StudioBrandDraftUpdate(config=_config(), expectedVersion=3), membership))
    assert error.value.status_code == 409


def test_draft_cannot_cross_resolved_tenant():
    membership = (User(id=str(uuid4()), email='editor@example.test'), TenantContext('chef-1', 'ohorodnik-oleksandr'), 'editor')
    with pytest.raises(HTTPException) as error:
        asyncio.run(update_brand_draft(StudioBrandDraftUpdate(config=_config('other-tenant'), expectedVersion=1), membership))
    assert error.value.status_code == 422
