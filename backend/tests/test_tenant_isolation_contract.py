import asyncio
from datetime import datetime, timezone
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.api.v1.endpoints import recipes
from app.api.v1.endpoints.auth import User
from app.core.tenant import TenantContext


def _row(*, recipe_id, chef_id, premium=False):
    now = datetime.now(timezone.utc).isoformat()
    return {
        'id': recipe_id, 'chef_id': chef_id, 'title': 'Same title',
        'description': 'Metadata remains discoverable', 'is_public': True,
        'is_premium': premium, 'difficulty_level': 1, 'prep_time_minutes': 1,
        'cook_time_minutes': 1, 'servings': 1, 'instructions_structured': ['secret step'],
        'video_url': 'https://youtu.be/private-video', 'tags': [], 'created_at': now,
        'updated_at': now, 'recipe_ingredients': [], 'recipe_nutrition': [],
    }


def test_cross_tenant_detail_is_indistinguishable_from_missing(monkeypatch):
    tenant_a = TenantContext(chef_id=str(uuid4()), slug='tenant-a')
    tenant_b = str(uuid4())
    recipe_id = str(uuid4())
    calls = []

    async def get_recipe_by_id(received_recipe_id, received_chef_id):
        calls.append((received_recipe_id, received_chef_id))
        return {'data': []}

    monkeypatch.setattr(recipes.supabase_service, 'get_recipe_by_id', get_recipe_by_id)
    with pytest.raises(HTTPException) as error:
        asyncio.run(recipes.get_recipe(recipe_id, None, tenant_a))

    assert error.value.status_code == 404
    assert calls == [(recipe_id, tenant_a.chef_id)]
    assert tenant_b != tenant_a.chef_id


def test_guest_gets_premium_teaser_without_protected_body(monkeypatch):
    tenant = TenantContext(chef_id=str(uuid4()), slug='tenant-a')
    recipe_id = str(uuid4())

    async def get_recipe_by_id(_recipe_id, chef_id):
        assert chef_id == tenant.chef_id
        return {'data': [_row(recipe_id=recipe_id, chef_id=tenant.chef_id, premium=True)]}

    monkeypatch.setattr(recipes.supabase_service, 'get_recipe_by_id', get_recipe_by_id)
    result = asyncio.run(recipes.get_recipe(recipe_id, None, tenant))

    assert result.is_locked is True
    assert result.instructions == []
    assert result.ingredients == []
    assert result.video_url is None


def test_tenant_member_can_read_own_private_body(monkeypatch):
    tenant = TenantContext(chef_id=str(uuid4()), slug='tenant-a')
    recipe_id = str(uuid4())
    row = _row(recipe_id=recipe_id, chef_id=tenant.chef_id, premium=True)
    row['recipe_ingredients'] = [{'id': str(uuid4()), 'recipe_id': recipe_id, 'display_name': 'Secret'}]

    async def get_recipe_by_id(_recipe_id, _chef_id):
        return {'data': [row]}

    monkeypatch.setattr(recipes.supabase_service, 'get_recipe_by_id', get_recipe_by_id)
    result = asyncio.run(recipes.get_recipe(
        recipe_id, User(id=str(uuid4()), email='member@example.com', chef_id=tenant.chef_id), tenant,
    ))
    assert result.is_locked is False
    assert result.instructions == ['secret step']
