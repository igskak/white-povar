import asyncio
from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from app.api.v1.endpoints import recipes
from app.api.v1.endpoints.auth import User
from app.core.tenant import TenantContext


def _user():
    return User(id='00000000-0000-0000-0000-000000000123', email='user@example.com')


def _tenant():
    return TenantContext(slug='ohorodnik-oleksandr', chef_id='00000000-0000-0000-0000-000000000456')


def test_history_event_uses_resolved_tenant_and_authenticated_user(monkeypatch):
    calls = []

    async def recipe_exists(recipe_id, chef_id):
        assert chef_id == _tenant().chef_id
        return SimpleNamespace(data=[{'id': recipe_id}])

    async def record(user_id, chef_id, recipe_id, event):
        calls.append((user_id, chef_id, recipe_id, event))

    monkeypatch.setattr(recipes.supabase_service, 'get_recipe_by_id', recipe_exists)
    monkeypatch.setattr(recipes.supabase_service, 'record_recipe_history', record)

    response = asyncio.run(recipes.record_recipe_history(
        '00000000-0000-0000-0000-000000000789', 'viewed', _user(), _tenant(),
    ))

    assert response is None
    assert calls == [(_user().id, _tenant().chef_id, '00000000-0000-0000-0000-000000000789', 'viewed')]


def test_history_event_rejects_unknown_event():
    with pytest.raises(HTTPException) as error:
        asyncio.run(recipes.record_recipe_history(
            '00000000-0000-0000-0000-000000000789', 'deleted', _user(), _tenant(),
        ))
    assert error.value.status_code == 400
