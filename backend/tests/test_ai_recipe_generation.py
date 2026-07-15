import asyncio
from datetime import datetime, timezone
from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.api.v1.endpoints.auth import User
from app.core.tenant import TenantContext
from app.schemas.ai_generation import RecipeGenerationRequest
from app.services.recipe_generation_service import RecipeGenerationService


def _row(tenant_id):
    return {
        'id': str(uuid4()), 'chef_id': tenant_id, 'title': 'Томатний суп',
        'tags': ['сезонне', 'овочі'], 'content_kind': 'recipe',
        'description': 'This must never reach the model',
        'instructions_structured': ['This must never reach the model'],
        'recipe_ingredients': [{'display_name': 'secret premium ingredient'}],
        'is_public': True, 'is_premium': True,
        'created_at': datetime.now(timezone.utc).isoformat(),
    }


def test_generation_requires_explicit_per_request_consent():
    with pytest.raises(ValidationError):
        RecipeGenerationRequest(prompt='легка вечеря', generation_consent=False)


def test_unsafe_generation_is_rejected_before_retrieval_or_model(monkeypatch):
    service = RecipeGenerationService()
    tenant = TenantContext(chef_id=str(uuid4()), slug='ohorodnik-oleksandr')
    called = False

    async def fake_references(*_args):
        nonlocal called
        called = True
        return []

    monkeypatch.setattr(service, '_allowed_references', fake_references)
    with pytest.raises(Exception, match='медичних'):
        asyncio.run(service.generate(
            RecipeGenerationRequest(prompt='порадь лікування кашлю', generation_consent=True),
            User(id=str(uuid4()), email='test@example.com'), tenant, _status,
        ))
    assert called is False


def test_generation_uses_only_tenant_metadata_and_returns_ai_label(monkeypatch):
    service = RecipeGenerationService()
    tenant = TenantContext(chef_id=str(uuid4()), slug='ohorodnik-oleksandr')
    user = User(id=str(uuid4()), email='test@example.com')
    captured = {}

    class Result:
        data = [_row(tenant.chef_id)]

    async def fake_search(**kwargs):
        captured['search'] = kwargs
        return Result()

    async def fake_model(_request, _profile, references):
        captured['references'] = references
        return {
            'title': 'Овочева вечеря', 'description': 'Тепла проста страва.',
            'servings': 2, 'total_time_minutes': 30,
            'ingredients': [{'name': 'томати', 'amount': '400 г'}],
            'steps': ['Наріжте томати та прогрійте 15 хвилин.'],
            'safety_note': 'Перевірте склад продуктів щодо власних алергенів.',
        }

    from app.services.recipe_generation_service import supabase_service
    monkeypatch.setattr(supabase_service, 'search_catalog_recipes', fake_search)
    monkeypatch.setattr(service, '_call_model', fake_model)

    recipe = asyncio.run(service.generate(
        RecipeGenerationRequest(prompt='вечеря з томатами', generation_consent=True),
        user, tenant, _status,
    ))

    assert captured['search']['chef_id'] == tenant.chef_id
    assert captured['references'] == [{
        'title': 'Томатний суп', 'tags': ['сезонне', 'овочі'], 'content_kind': 'recipe',
    }]
    assert 'secret premium ingredient' not in str(captured['references'])
    assert recipe.source == 'ai_generated'
    assert recipe.attribution == 'Створено AI, не опублікований рецепт автора'


async def _status(_message):
    return None
