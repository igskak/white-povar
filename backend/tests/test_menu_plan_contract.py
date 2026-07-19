import asyncio
from datetime import date
from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from app.api.v1.endpoints import menu_plans
from app.schemas.menu_plan import MenuPlanSlotInput
from app.services.database import SupabaseService


def _user():
    return SimpleNamespace(id='user-1')


def _tenant():
    return SimpleNamespace(chef_id='tenant-1')


def test_menu_plan_slot_is_tenant_bound_without_entitlement_check(monkeypatch):
    item = MenuPlanSlotInput(planned_for=date(2026, 7, 20), recipe_id='recipe-1', servings=4)
    calls = []

    async def recipe(recipe_id, chef_id, collection_id):
        calls.append((recipe_id, chef_id, collection_id))
        return {'id': recipe_id, 'title': 'Суп', 'is_premium': True}

    async def create(user_id, chef_id, payload, recipe):
        assert recipe['is_premium'] is True
        return {'id': 'slot-1', **payload, 'title': recipe['title'], 'is_premium': True}

    monkeypatch.setattr(menu_plans.supabase_service, 'get_menu_plan_recipe', recipe)
    monkeypatch.setattr(menu_plans.supabase_service, 'create_menu_plan_slot', create)
    result = asyncio.run(menu_plans.add_menu_plan_slot(item, _user(), _tenant()))
    assert calls == [('recipe-1', 'tenant-1', None)]
    assert result['is_premium'] is True


def test_week_start_must_be_monday(monkeypatch):
    async def ignored(*_args):
        raise AssertionError('database should not be reached')
    monkeypatch.setattr(menu_plans.supabase_service, 'get_menu_plan_slots', ignored)
    with pytest.raises(HTTPException, match='Monday'):
        asyncio.run(menu_plans.get_menu_plan(date(2026, 7, 21), _user(), _tenant()))


def test_reorder_rejects_a_foreign_slot(monkeypatch):
    async def reorder(*_args):
        raise ValueError('Menu plan slots must belong to the current user and tenant')
    monkeypatch.setattr(menu_plans.supabase_service, 'reorder_menu_plan_slots', reorder)
    with pytest.raises(HTTPException) as error:
        asyncio.run(menu_plans.reorder_menu_plan(
            menu_plans.MenuPlanReorder(slot_ids=['foreign']), date(2026, 7, 20), _user(), _tenant()))
    assert error.value.status_code == 404


def test_menu_slot_serializes_date_before_postgrest_insert(monkeypatch):
    payloads = []

    class Query:
        def insert(self, payload):
            payloads.append(payload)
            return self

        def execute(self):
            return SimpleNamespace(data=[{'id': 'slot-1'}])

    class Client:
        def table(self, table):
            assert table == 'menu_plan_slots'
            return Query()

    service = object.__new__(SupabaseService)
    monkeypatch.setattr(service, 'get_client', lambda use_service_key: Client())
    asyncio.run(service.create_menu_plan_slot(
        'user-1', 'tenant-1',
        {'planned_for': date(2026, 7, 20), 'recipe_id': 'recipe-1', 'servings': 2},
        {'title': 'Суп', 'is_premium': False, 'image_url': None},
    ))

    assert payloads[0]['planned_for'] == '2026-07-20'
