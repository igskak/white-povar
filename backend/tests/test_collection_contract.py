import asyncio
from datetime import datetime, timezone
from uuid import uuid4

import pytest
from fastapi import HTTPException
from starlette.requests import Request

from app.api.v1.endpoints import collections
from app.api.v1.endpoints.auth import User
from app.core.tenant import TenantContext


def _request(language='uk'):
    return Request({
        'type': 'http', 'method': 'GET', 'query_string': b'',
        'headers': [(b'accept-language', language.encode())],
    })


def _content(recipe_id, chef_id):
    now = datetime.now(timezone.utc).isoformat()
    return {
        'id': recipe_id, 'chef_id': chef_id, 'title': 'Техніка', 'description': 'Деталі',
        'content_kind': 'technique', 'is_public': True, 'is_premium': False,
        'difficulty_level': 1, 'prep_time_minutes': 0, 'cook_time_minutes': 0,
        'servings': 1, 'instructions_structured': ['Секретний крок'], 'tags': [],
        'created_at': now, 'updated_at': now, 'recipe_ingredients': [], 'recipe_nutrition': [],
    }


def _collection(collection_id, chef_id, *, premium=True, items=None):
    return {
        'id': collection_id, 'chef_id': chef_id, 'slug': 'maisternia',
        'title_i18n': {'uk': 'Майстерня', 'en': 'Workshop'},
        'description_i18n': {'uk': 'Опис', 'en': 'Description'}, 'cover_url': 'https://example.com/cover.jpg',
        'is_premium': premium, 'published_at': datetime.now(timezone.utc).isoformat(),
        'collection_items': items or [],
    }


class _Result:
    def __init__(self, data, count=None):
        self.data = data
        self.count = count


def test_collection_list_is_tenant_scoped_localized_and_marks_premium_teaser(monkeypatch):
    tenant = TenantContext(chef_id=str(uuid4()), slug='tenant-a')
    row = _collection(str(uuid4()), tenant.chef_id)
    row['collection_items'] = [{'count': 2}]
    calls = []

    async def get_published(chef_id, limit, offset):
        calls.append((chef_id, limit, offset))
        return _Result([row], count=1)

    monkeypatch.setattr(collections.supabase_service, 'get_published_collections', get_published)
    result = asyncio.run(collections.get_collections(_request('en'), 20, 0, None, tenant))

    assert calls == [(tenant.chef_id, 20, 0)]
    assert result.total_count == 1
    assert result.collections[0].title == 'Workshop'
    assert result.collections[0].item_count == 2
    assert result.collections[0].is_locked is True


def test_locked_collection_preserves_stable_order_but_never_returns_body(monkeypatch):
    tenant = TenantContext(chef_id=str(uuid4()), slug='tenant-a')
    collection_id, first_id, second_id = (str(uuid4()) for _ in range(3))
    row = _collection(collection_id, tenant.chef_id, items=[
        {'id': str(uuid4()), 'position': 2, 'is_preview': False, 'content': _content(second_id, tenant.chef_id)},
        {'id': str(uuid4()), 'position': 1, 'is_preview': False, 'content': _content(first_id, tenant.chef_id)},
    ])

    async def get_one(received_id, chef_id):
        assert (received_id, chef_id) == (collection_id, tenant.chef_id)
        return _Result([row])

    monkeypatch.setattr(collections.supabase_service, 'get_published_collection_by_id', get_one)
    result = asyncio.run(collections.get_collection(collection_id, _request(), None, tenant))

    assert result.is_locked is True
    assert [item.position for item in result.items] == [1, 2]
    assert all(item.content.is_locked for item in result.items)
    assert all(item.content.instructions == [] for item in result.items)


def test_unpublished_or_cross_tenant_collection_is_not_visible(monkeypatch):
    tenant = TenantContext(chef_id=str(uuid4()), slug='tenant-a')
    collection_id = str(uuid4())

    async def missing(received_id, chef_id):
        assert (received_id, chef_id) == (collection_id, tenant.chef_id)
        return _Result([])

    monkeypatch.setattr(collections.supabase_service, 'get_published_collection_by_id', missing)
    with pytest.raises(HTTPException) as error:
        asyncio.run(collections.get_collection(collection_id, _request(), None, tenant))
    assert error.value.status_code == 404


def test_tenant_member_reads_ordered_collection_body(monkeypatch):
    tenant = TenantContext(chef_id=str(uuid4()), slug='tenant-a')
    collection_id, recipe_id = str(uuid4()), str(uuid4())
    row = _collection(collection_id, tenant.chef_id, items=[
        {'id': str(uuid4()), 'position': 0, 'is_preview': False, 'content': _content(recipe_id, tenant.chef_id)},
    ])

    async def get_one(*_args):
        return _Result([row])

    monkeypatch.setattr(collections.supabase_service, 'get_published_collection_by_id', get_one)
    user = User(id=str(uuid4()), email='member@example.com', chef_id=tenant.chef_id)
    result = asyncio.run(collections.get_collection(collection_id, _request(), user, tenant))
    assert result.is_locked is False
    assert result.items[0].content.instructions == ['Секретний крок']


def test_collection_migration_allows_one_content_item_in_multiple_collections():
    migration = (collections.__file__.replace('app/api/v1/endpoints/collections.py', 'migrations/2026_07_15_collections.sql'))
    with open(migration, encoding='utf-8') as source:
        sql = source.read()
    assert 'UNIQUE (collection_id, recipe_id)' in sql
    assert 'UNIQUE (recipe_id)' not in sql
    assert 'enforce_collection_item_tenant' in sql
