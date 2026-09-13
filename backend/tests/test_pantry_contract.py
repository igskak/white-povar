import asyncio
from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from app.api.v1.endpoints import pantry
from app.api.v1.endpoints.auth import User
from app.core.tenant import TenantContext
from app.schemas.pantry import PantryItemInput, RecipeShoppingRequest, ShoppingList
from app.services.database import SupabaseService


def _user(): return User(id='user-a', email='a@example.com')
def _tenant(): return TenantContext(slug='tenant-a', chef_id='chef-a')


def test_low_confidence_camera_item_cannot_be_silently_added():
    with pytest.raises(HTTPException) as error:
        asyncio.run(pantry.add_pantry_item(PantryItemInput(name='tomato', source='camera', confidence=.4, confirmed=False), _user(), _tenant()))
    assert error.value.status_code == 422


def test_pantry_and_shopping_calls_are_scoped_to_user_and_tenant(monkeypatch):
    calls = []
    async def create_pantry(user, chef, data):
        calls.append(('pantry', user, chef, data)); return {**data, 'id': 'p1'}
    async def add_recipe(user, chef, recipe, servings):
        calls.append(('recipe', user, chef, recipe, servings)); return []
    async def recipe(recipe_id, chef):
        calls.append(('lookup', recipe_id, chef)); return {'data': [{'id': recipe_id, 'servings': 2, 'recipe_ingredients': []}]}
    monkeypatch.setattr(pantry.supabase_service, 'create_pantry_item', create_pantry)
    monkeypatch.setattr(pantry.supabase_service, 'add_recipe_missing_ingredients', add_recipe)
    monkeypatch.setattr(pantry.supabase_service, 'get_recipe_by_id', recipe)
    added = asyncio.run(pantry.add_pantry_item(PantryItemInput(name=' Tomato '), _user(), _tenant()))
    assert added['name'] == 'tomato'
    asyncio.run(pantry.add_recipe_to_shopping_list('recipe-a', RecipeShoppingRequest(servings=4), _user(), _tenant()))
    assert calls[0][1:3] == ('user-a', 'chef-a')
    assert calls[-1][1:3] == ('user-a', 'chef-a')


def test_pantry_database_payload_excludes_api_only_confirmation(monkeypatch):
    payloads = []

    class Query:
        def insert(self, payload):
            payloads.append(payload)
            return self

        def update(self, payload):
            payloads.append(payload)
            return self

        def eq(self, *_):
            return self

        def execute(self):
            return SimpleNamespace(data=[{'id': 'p1'}])

    class Client:
        def table(self, table):
            assert table == 'pantry_items'
            return Query()

    service = object.__new__(SupabaseService)
    monkeypatch.setattr(service, 'get_client', lambda use_service_key: Client())
    data = {'name': 'tomato', 'source': 'camera', 'confidence': .9, 'confirmed': True}
    asyncio.run(service.create_pantry_item('user-a', 'chef-a', data))
    asyncio.run(service.update_pantry_item('p1', 'user-a', 'chef-a', data))

    assert all('confirmed' not in payload for payload in payloads)
    assert payloads[0]['user_id'] == 'user-a'


def test_recipe_ingredients_land_in_shopping_list_with_readable_units(monkeypatch):
    """A recipe row carries unit_id, a UUID; the shopping list shows units.

    Storing the raw id broke the 24-char unit contract, so the add answered
    422 after the insert had already committed and every later read failed.
    """
    stored = [{'id': 'old', 'name': 'сіль', 'unit': '00000000-0000-0000-0000-000000000001', 'category': 'Інше'}]

    class Query:
        def insert(self, payload):
            stored.extend({**row, 'id': f'new-{i}'} for i, row in enumerate(payload))
            return self

        def select(self, *_):
            return self

        def eq(self, *_):
            return self

        def order(self, *_):
            return self

        def execute(self):
            return SimpleNamespace(data=[dict(row) for row in stored])

    class Client:
        def table(self, table):
            return Query()

    async def pantry_items(*_):
        return []

    service = object.__new__(SupabaseService)
    monkeypatch.setattr(service, 'get_client', lambda use_service_key: Client())
    monkeypatch.setattr(service, 'get_pantry_items', pantry_items)
    recipe = {'id': 'r1', 'servings': 4, 'recipe_ingredients': [
        {'display_name': 'Буряк', 'amount': 500, 'unit_id': '00000000-0000-0000-0000-000000000001'},
        {'display_name': 'Сіль', 'amount': None, 'unit_id': None},
    ]}

    items = asyncio.run(service.add_recipe_missing_ingredients('user-a', 'chef-a', recipe, 4))

    shopping = ShoppingList(items=items)
    units = [(item.id, item.name, item.unit) for item in shopping.items]
    assert ('new-0', 'буряк', 'г') in units
    assert ('new-1', 'сіль', None) in units
    assert ('old', 'сіль', 'г') in units
