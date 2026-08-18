import asyncio
from datetime import datetime, timezone
from uuid import uuid4

import pytest
from fastapi import HTTPException
from starlette.requests import Request

from app.api.v1.endpoints import collections, recipes
from app.api.v1.endpoints.auth import User
from app.core.tenant import TenantContext
from app.services.subscription_service import subscription_service


def _request(language='uk'):
    return Request({
        'type': 'http', 'method': 'GET', 'query_string': b'',
        'headers': [(b'accept-language', language.encode())],
    })


def _content(recipe_id, chef_id, *, premium=False):
    now = datetime.now(timezone.utc).isoformat()
    return {
        'id': recipe_id, 'chef_id': chef_id, 'title': 'Техніка', 'description': 'Деталі',
        'content_kind': 'technique', 'is_public': True, 'is_premium': premium,
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


def test_free_preview_opens_its_premium_item_but_not_the_rest(monkeypatch):
    """The badge promises a readable material, so the projection must deliver one."""
    tenant = TenantContext(chef_id=str(uuid4()), slug='tenant-a')
    collection_id, preview_id, paid_id = (str(uuid4()) for _ in range(3))
    row = _collection(collection_id, tenant.chef_id, items=[
        {'id': str(uuid4()), 'position': 0, 'is_preview': True,
         'content': _content(preview_id, tenant.chef_id, premium=True)},
        {'id': str(uuid4()), 'position': 1, 'is_preview': False,
         'content': _content(paid_id, tenant.chef_id, premium=True)},
    ])

    async def get_one(*_args):
        return _Result([row])

    monkeypatch.setattr(collections.supabase_service, 'get_published_collection_by_id', get_one)
    result = asyncio.run(collections.get_collection(collection_id, _request(), None, tenant))

    assert result.is_locked is True
    preview, paid = result.items
    assert preview.is_preview is True
    assert preview.content.is_locked is False
    assert preview.content.instructions == ['Секретний крок']
    assert paid.content.is_locked is True
    assert paid.content.instructions == []


def test_free_preview_item_hides_a_recipe_the_tenant_never_published(monkeypatch):
    """A preview flag grants premium reading, never cross-tenant visibility."""
    tenant = TenantContext(chef_id=str(uuid4()), slug='tenant-a')
    collection_id = str(uuid4())
    foreign = _content(str(uuid4()), str(uuid4()), premium=True)
    row = _collection(collection_id, tenant.chef_id, items=[
        {'id': str(uuid4()), 'position': 0, 'is_preview': True, 'content': foreign},
    ])

    async def get_one(*_args):
        return _Result([row])

    monkeypatch.setattr(collections.supabase_service, 'get_published_collection_by_id', get_one)
    result = asyncio.run(collections.get_collection(collection_id, _request(), None, tenant))

    assert result.items == []


def _premium_recipe_route(monkeypatch, tenant, recipe_id, *, item, calls=None):
    """Serve one premium recipe, with whatever the named collection claims of it."""
    row = _content(recipe_id, tenant.chef_id, premium=True)
    row['instructions'] = ['Секретний крок']

    async def get_recipe_by_id(_recipe_id, _chef_id):
        return {'data': [row]}

    async def get_collection_item_grant(received_recipe, received_collection, received_chef):
        if calls is not None:
            calls.append((received_recipe, received_collection, received_chef))
        return item

    monkeypatch.setattr(recipes.supabase_service, 'get_recipe_by_id', get_recipe_by_id)
    monkeypatch.setattr(
        recipes.supabase_service, 'get_collection_item_grant', get_collection_item_grant,
    )


def _item_grant(collection_id, chef_id, *, preview=False, premium=True):
    return {
        'is_preview': preview,
        'collections': {
            'id': collection_id, 'chef_id': chef_id,
            'is_premium': premium, 'status': 'published',
        },
    }


def _owns_collection(monkeypatch, user_id, chef_id, collection_id):
    """Grant a real one-off entitlement rather than stubbing the decision."""
    async def get_entitlements(received_user, received_chef):
        assert (received_user, received_chef) == (user_id, chef_id)
        return [{
            'status': 'active', 'scope_type': 'collection',
            'collection_id': collection_id, 'expires_at': None, 'starts_at': None,
            'product': {
                'kind': 'one_off',
                'product_content': [{'collection_id': collection_id}],
            },
        }]

    monkeypatch.setattr(
        subscription_service.db_service, 'get_commerce_entitlements', get_entitlements,
    )


def test_free_preview_grant_opens_the_same_recipe_on_its_own_route(monkeypatch):
    """Opening the item from the collection must not re-lock what it showed as free."""
    tenant = TenantContext(chef_id=str(uuid4()), slug='tenant-a')
    recipe_id, collection_id = str(uuid4()), str(uuid4())
    calls = []
    _premium_recipe_route(
        monkeypatch, tenant, recipe_id, calls=calls,
        item=_item_grant(collection_id, tenant.chef_id, preview=True),
    )

    result = asyncio.run(recipes.get_recipe(recipe_id, collection_id, None, tenant))

    assert result.is_locked is False
    assert result.instructions == ['Секретний крок']
    assert calls == [(recipe_id, collection_id, tenant.chef_id)]


def test_a_forged_collection_claim_never_opens_a_premium_recipe(monkeypatch):
    """The client names a collection; only the server decides what it granted."""
    tenant = TenantContext(chef_id=str(uuid4()), slug='tenant-a')
    recipe_id = str(uuid4())
    # No row comes back for a collection that does not carry this recipe.
    _premium_recipe_route(monkeypatch, tenant, recipe_id, item=None)

    result = asyncio.run(recipes.get_recipe(recipe_id, str(uuid4()), None, tenant))

    assert result.is_locked is True
    assert result.instructions == []


def test_a_malformed_collection_hint_is_no_grant_and_no_error(monkeypatch):
    tenant = TenantContext(chef_id=str(uuid4()), slug='tenant-a')
    recipe_id = str(uuid4())
    calls = []
    _premium_recipe_route(
        monkeypatch, tenant, recipe_id, calls=calls,
        item=_item_grant(str(uuid4()), tenant.chef_id, preview=True),
    )

    result = asyncio.run(recipes.get_recipe(recipe_id, 'not-a-uuid', None, tenant))

    assert result.is_locked is True
    assert calls == []


def test_buying_one_collection_opens_its_material_on_the_recipe_route(monkeypatch):
    """The collection screen shows a bought material readable; so must the route."""
    tenant = TenantContext(chef_id=str(uuid4()), slug='tenant-a')
    recipe_id, collection_id, user_id = (str(uuid4()) for _ in range(3))
    _premium_recipe_route(
        monkeypatch, tenant, recipe_id,
        item=_item_grant(collection_id, tenant.chef_id),
    )
    _owns_collection(monkeypatch, user_id, tenant.chef_id, collection_id)
    buyer = User(id=user_id, email='buyer@example.com', chef_id=None)
    # One collection is all this buyer holds — no tenant-wide premium to lean on.
    assert not asyncio.run(
        subscription_service.has_tenant_entitlement(user_id, tenant.chef_id))

    result = asyncio.run(recipes.get_recipe(recipe_id, collection_id, buyer, tenant))

    assert result.is_locked is False
    assert result.instructions == ['Секретний крок']


def test_a_premium_collection_stays_shut_for_someone_who_never_bought_it(monkeypatch):
    tenant = TenantContext(chef_id=str(uuid4()), slug='tenant-a')
    recipe_id, collection_id, other_collection = (str(uuid4()) for _ in range(3))
    user_id = str(uuid4())
    _premium_recipe_route(
        monkeypatch, tenant, recipe_id,
        item=_item_grant(collection_id, tenant.chef_id),
    )
    # The entitlement this viewer holds is for a different collection.
    _owns_collection(monkeypatch, user_id, tenant.chef_id, other_collection)
    viewer = User(id=user_id, email='viewer@example.com', chef_id=None)

    result = asyncio.run(recipes.get_recipe(recipe_id, collection_id, viewer, tenant))

    assert result.is_locked is True
    assert result.instructions == []


def test_an_embedded_collection_is_read_as_an_object_or_a_single_row(monkeypatch):
    """PostgREST shapes a parent embed either way; ownership must survive both."""
    tenant = TenantContext(chef_id=str(uuid4()), slug='tenant-a')
    recipe_id, collection_id, user_id = (str(uuid4()) for _ in range(3))
    grant = _item_grant(collection_id, tenant.chef_id)
    grant['collections'] = [grant['collections']]
    _premium_recipe_route(monkeypatch, tenant, recipe_id, item=grant)
    _owns_collection(monkeypatch, user_id, tenant.chef_id, collection_id)
    buyer = User(id=user_id, email='buyer@example.com', chef_id=None)

    result = asyncio.run(recipes.get_recipe(recipe_id, collection_id, buyer, tenant))

    assert result.is_locked is False


def test_a_guest_gets_nothing_from_naming_a_premium_collection(monkeypatch):
    tenant = TenantContext(chef_id=str(uuid4()), slug='tenant-a')
    recipe_id, collection_id = str(uuid4()), str(uuid4())
    _premium_recipe_route(
        monkeypatch, tenant, recipe_id,
        item=_item_grant(collection_id, tenant.chef_id),
    )

    result = asyncio.run(recipes.get_recipe(recipe_id, collection_id, None, tenant))

    assert result.is_locked is True
    assert result.instructions == []
