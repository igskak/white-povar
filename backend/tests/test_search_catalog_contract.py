import asyncio
from datetime import datetime, timezone
from uuid import uuid4

from app.api.v1.endpoints import search
from app.core.tenant import TenantContext


def _row(recipe_id, chef_id, *, premium=False, tags=None):
    now = datetime.now(timezone.utc).isoformat()
    return {
        'id': recipe_id,
        'chef_id': chef_id,
        'title': 'Борщ',
        'description': 'Тестовий рецепт',
        'is_public': True,
        'is_premium': premium,
        'difficulty_level': 2,
        'prep_time_minutes': 10,
        'cook_time_minutes': 20,
        'servings': 4,
        'instructions_structured': ['Прихований крок'],
        'tags': tags or ['швидко'],
        'created_at': now,
        'updated_at': now,
        'recipe_ingredients': [],
        'recipe_nutrition': [],
    }


def test_catalog_search_is_tenant_scoped_stable_and_keeps_premium_teaser(monkeypatch):
    tenant = TenantContext(chef_id=str(uuid4()), slug='tenant-a')
    captured = {}
    first = _row(str(uuid4()), tenant.chef_id, premium=True,
                 tags=['maisternia-oleksandra'])
    second = _row(str(uuid4()), tenant.chef_id)

    class Result:
        data = [first, second]
        count = 3

    async def fake_search(**kwargs):
        captured.update(kwargs)
        return Result()

    monkeypatch.setattr(search.supabase_service, 'search_catalog_recipes', fake_search)

    result = asyncio.run(search.search_catalog(
        q='борщ', tags=['MAISTERNIA-OLEKSANDRA'], difficulty=2,
        max_total_time=30, is_featured=None, limit=2, offset=2,
        current_user=None, tenant=tenant,
    ))

    assert captured == {
        'chef_id': tenant.chef_id,
        'query_text': 'борщ',
        'tags': ['maisternia-oleksandra'],
        'difficulty': 2,
        'max_total_time': 30,
        'is_featured': None,
        'limit': 2,
        'offset': 2,
    }
    assert result.total_count == 3
    assert result.has_more is False
    assert result.next_offset is None
    assert result.recipes[0].is_locked is True
    assert result.recipes[0].instructions == []
    assert result.recipes[1].is_locked is False


def test_catalog_search_uses_offset_metadata_without_client_full_list(monkeypatch):
    tenant = TenantContext(chef_id=str(uuid4()), slug='tenant-a')

    class Result:
        data = [_row(str(uuid4()), tenant.chef_id)]
        count = 4

    async def fake_search(**_):
        return Result()

    monkeypatch.setattr(search.supabase_service, 'search_catalog_recipes', fake_search)
    result = asyncio.run(search.search_catalog(
        q=None, tags=None, difficulty=None, max_total_time=None,
        is_featured=None, limit=2, offset=0, current_user=None, tenant=tenant,
    ))

    assert result.has_more is True
    assert result.next_offset == 2
