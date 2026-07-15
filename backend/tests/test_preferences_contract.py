import asyncio

import pytest
from fastapi import HTTPException

from app.api.v1.endpoints import auth
from app.core.tenant import TenantContext
from app.schemas.preferences import PreferenceProfile


def _user():
    return auth.User(id='user-a', email='a@example.com')


def _tenant():
    return TenantContext(slug='tenant-a', chef_id='chef-a')


def test_preferences_require_explicit_consent_to_persist():
    with pytest.raises(HTTPException) as error:
        asyncio.run(auth.save_preferences(
            PreferenceProfile(allergens=['nuts'], personalization_consent=False),
            _user(), _tenant(),
        ))
    assert error.value.status_code == 422


def test_preferences_are_saved_and_reset_inside_resolved_tenant(monkeypatch):
    calls = []

    async def upsert(user_id, chef_id, data):
        calls.append(('upsert', user_id, chef_id, data))

    async def get(user_id, chef_id):
        calls.append(('get', user_id, chef_id))
        return {
            'diets': ['vegan'], 'allergens': ['nuts'], 'dislikes': [],
            'equipment': [], 'preferred_max_total_time': 30,
            'household_size': 2, 'personalization_consent': True,
        }

    async def delete(user_id, chef_id):
        calls.append(('delete', user_id, chef_id))

    monkeypatch.setattr(auth.supabase_service, 'upsert_preference_profile', upsert)
    monkeypatch.setattr(auth.supabase_service, 'get_preference_profile', get)
    monkeypatch.setattr(auth.supabase_service, 'delete_preference_profile', delete)
    saved = asyncio.run(auth.save_preferences(
        PreferenceProfile(diets=[' Vegan '], allergens=['NUTS'], preferred_max_total_time=30,
            household_size=2, personalization_consent=True), _user(), _tenant(),
    ))
    assert saved.diets == ['vegan']
    assert calls[0][1:3] == ('user-a', 'chef-a')

    assert asyncio.run(auth.reset_preferences(_user(), _tenant())) is None
    assert calls[-1] == ('delete', 'user-a', 'chef-a')
