import asyncio
from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import uuid4

from app.api.v1.endpoints.auth import User
from app.api.v1.endpoints import collections
from app.core.collection_access import resolve_collection_access
from app.core.tenant import TenantContext
from app.services.subscription_service import subscription_service
from starlette.requests import Request


def _entitlement(*, kind, status='active', scope='tenant', collection_id=None,
                 expires_at=None, mapped_collection_ids=()):
    return {
        'status': status,
        'scope_type': scope,
        'collection_id': collection_id,
        'expires_at': expires_at,
        'starts_at': None,
        'product': {
            'kind': kind,
            'product_content': [{'collection_id': value} for value in mapped_collection_ids],
        },
    }


def test_access_accepts_active_trial_and_grace_but_rejects_terminal_or_expired(monkeypatch):
    user_id, chef_id = str(uuid4()), str(uuid4())

    async def access_for(rows):
        async def get_entitlements(*_args):
            return rows

        monkeypatch.setattr(subscription_service.db_service, 'get_commerce_entitlements', get_entitlements)
        return await subscription_service.has_tenant_entitlement(user_id, chef_id)

    for status in ('active', 'trial', 'grace'):
        assert asyncio.run(access_for([_entitlement(kind='subscription', status=status)]))
    for status in ('expired', 'refunded', 'revoked'):
        assert not asyncio.run(access_for([_entitlement(kind='subscription', status=status)]))
    expired = (datetime.now(timezone.utc) - timedelta(seconds=1)).isoformat()
    assert not asyncio.run(access_for([_entitlement(kind='subscription', expires_at=expired)]))
    future = _entitlement(kind='subscription')
    future['starts_at'] = (datetime.now(timezone.utc) + timedelta(seconds=1)).isoformat()
    assert not asyncio.run(access_for([future]))


def test_one_off_needs_matching_scope_and_product_content_mapping(monkeypatch):
    user_id, chef_id = str(uuid4()), str(uuid4())
    owned_collection, other_collection = str(uuid4()), str(uuid4())
    rows = [_entitlement(
        kind='one_off', scope='collection', collection_id=owned_collection,
        mapped_collection_ids=(owned_collection,),
    )]

    async def get_entitlements(*_args):
        return rows

    monkeypatch.setattr(subscription_service.db_service, 'get_commerce_entitlements', get_entitlements)
    assert asyncio.run(subscription_service.has_collection_entitlement(user_id, chef_id, owned_collection))
    assert not asyncio.run(subscription_service.has_collection_entitlement(user_id, chef_id, other_collection))

    rows[0]['product']['product_content'] = [{'collection_id': other_collection}]
    assert not asyncio.run(subscription_service.has_collection_entitlement(user_id, chef_id, owned_collection))


def test_collection_access_uses_one_off_scope_without_expanding_tenant_access(monkeypatch):
    chef_id, user_id, collection_id = str(uuid4()), str(uuid4()), str(uuid4())
    tenant = TenantContext(chef_id=chef_id, slug='tenant-a')
    collection = {'id': collection_id, 'chef_id': chef_id, 'is_premium': True}

    async def has_collection(*args):
        return args == (user_id, chef_id, collection_id)

    monkeypatch.setattr(subscription_service, 'has_collection_entitlement', has_collection)
    access = asyncio.run(resolve_collection_access(
        collection, tenant, User(id=user_id, email='buyer@example.com'),
    ))
    assert access.can_read_items


def test_owned_collection_returns_its_premium_body_without_widening_recipe_scope(monkeypatch):
    chef_id, user_id, collection_id, recipe_id = (str(uuid4()) for _ in range(4))
    now = datetime.now(timezone.utc).isoformat()
    row = {
        'id': collection_id, 'chef_id': chef_id, 'slug': 'owned',
        'title_i18n': {'uk': 'Власна'}, 'description_i18n': {'uk': 'Опис'},
        'is_premium': True, 'published_at': now,
        'collection_items': [{
            'id': str(uuid4()), 'position': 0, 'is_preview': False,
            'content': {
                'id': recipe_id, 'chef_id': chef_id, 'title': 'Закритий матеріал',
                'description': 'Опис', 'content_kind': 'technique', 'is_public': True,
                'is_premium': True, 'difficulty_level': 1, 'prep_time_minutes': 0,
                'cook_time_minutes': 0, 'servings': 1,
                'instructions_structured': ['Повний крок'], 'tags': [],
                'created_at': now, 'updated_at': now, 'recipe_ingredients': [],
                'recipe_nutrition': [],
            },
        }],
    }

    class Result:
        data = [row]

    async def get_collection(*_args):
        return Result()

    async def has_collection(*_args):
        return True

    monkeypatch.setattr(collections.supabase_service, 'get_published_collection_by_id', get_collection)
    monkeypatch.setattr(subscription_service, 'has_collection_entitlement', has_collection)
    request = Request({'type': 'http', 'method': 'GET', 'query_string': b'', 'headers': []})
    result = asyncio.run(collections.get_collection(
        collection_id, request, User(id=user_id, email='buyer@example.com'),
        TenantContext(chef_id=chef_id, slug='tenant-a'),
    ))
    assert result.is_locked is False
    assert result.items[0].content.instructions == ['Повний крок']


def test_commerce_migration_is_tenant_scoped_idempotent_and_has_no_price_authority():
    source = Path(__file__).resolve().parents[1] / 'migrations/2026_07_15_commerce_access.sql'
    sql = source.read_text(encoding='utf-8')
    assert 'CREATE TABLE IF NOT EXISTS public.products' in sql
    assert 'CREATE TABLE IF NOT EXISTS public.offers' in sql
    assert 'CREATE TABLE IF NOT EXISTS public.product_content' in sql
    assert 'CREATE TABLE IF NOT EXISTS public.commerce_entitlements' in sql
    assert "status IN ('active', 'trial', 'grace', 'expired', 'refunded', 'revoked')" in sql
    assert 'UNIQUE (provider, event_key)' in sql
    assert 'enforce_commerce_tenant_scope' in sql
    assert '\n    price' not in sql.lower()
