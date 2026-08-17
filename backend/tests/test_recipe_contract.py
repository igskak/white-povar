import asyncio
from datetime import datetime, timezone
from uuid import UUID, uuid4

import pytest

from app.api.v1.endpoints import recipes
from fastapi import HTTPException

from app.api.v1.endpoints.auth import User
from app.core.tenant import TenantContext
from app.schemas.recipe import RecipeCreate
from app.services.database import supabase_service


def test_public_payload_maps_to_canonical_recipe_tables():
    rows = recipes._recipe_payload_to_rows({
        'title': 'Pasta',
        'content_kind': 'process',
        'description': 'Fast dinner',
        'cuisine': 'Italian',
        'category': 'Second Courses',
        'difficulty': 2,
        'prep_time_minutes': 5,
        'cook_time_minutes': 10,
        'servings': 2,
        'instructions': ['Boil water', 'Cook pasta'],
        'images': ['https://example.com/pasta.jpg', 'ignored-by-current-schema.jpg'],
        'tags': ['quick'],
        'ingredients': [{
            'name': 'Salt', 'amount': 0, 'unit': 'g', 'notes': 'to taste', 'order': 0,
        }],
        'nutrition': {'calories': 450, 'protein_g': 15},
    })

    assert rows['difficulty_level'] == 2
    assert rows['content_kind'] == 'process'
    assert rows['instructions'] == 'Boil water\nCook pasta'
    assert rows['instructions_structured'] == ['Boil water', 'Cook pasta']
    assert rows['image_url'] == 'https://example.com/pasta.jpg'
    assert rows['ingredients'][0] == {
        'display_name': 'Salt',
        'amount': None,
        'unit_id': '00000000-0000-0000-0000-000000000001',
        'preparation_notes': 'to taste',
        'sort_order': 0,
    }
    assert rows['nutrition']['calories_per_serving'] == 450
    assert 'Italian' in rows['tags']
    assert 'difficulty' not in rows
    assert 'images' not in rows


def test_units_survive_a_read_then_write_round_trip():
    """The unit the API hands out must be a unit it accepts back.

    An editor saves what it was shown. When the read side started answering in
    Ukrainian, an English-only write map would have resolved every unit to None
    and quietly dropped it from the recipe.
    """
    for unit_id in recipes._UNIT_IDS.values():
        rendered = recipes._get_unit_name_from_id(unit_id)
        rows = recipes._recipe_payload_to_rows({
            'ingredients': [{'name': 'Сіль', 'amount': 5, 'unit': rendered, 'order': 0}],
        })
        assert rows['ingredients'][0]['unit_id'] == unit_id, rendered


def test_canonical_row_maps_back_to_frontend_contract():
    recipe_id = str(uuid4())
    chef_id = str(uuid4())
    ingredient_id = str(uuid4())
    nutrition_id = str(uuid4())
    now = datetime.now(timezone.utc).isoformat()

    recipe = recipes._recipe_from_row({
        'id': recipe_id,
        'chef_id': chef_id,
        'title': 'Pasta',
        'content_kind': 'process',
        'description': 'Fast dinner',
        'category_id': '20000000-0000-0000-0000-000000000003',
        'difficulty_level': 2,
        'prep_time_minutes': 5,
        'cook_time_minutes': 10,
        'total_time_minutes': 15,
        'servings': 2,
        'instructions': 'legacy text',
        'instructions_structured': ['Boil water', 'Cook pasta'],
        'image_url': 'https://example.com/pasta.jpg',
        'tags': ['italian'],
        'created_at': now,
        'updated_at': now,
        'recipe_ingredients': [{
            'id': ingredient_id,
            'recipe_id': recipe_id,
            'display_name': 'Pasta',
            'amount': '200.000',
            'unit_id': '00000000-0000-0000-0000-000000000001',
            'sort_order': 0,
        }],
        'recipe_nutrition': [{
            'id': nutrition_id,
            'recipe_id': recipe_id,
            'calories_per_serving': 450,
        }],
    })

    assert recipe.instructions == ['Boil water', 'Cook pasta']
    assert recipe.images == ['https://example.com/pasta.jpg']
    assert recipe.image_presentation.primary.url == (
        'https://example.com/pasta.jpg'
    )
    assert recipe.image_presentation.primary.focal.x == 0.5
    assert recipe.ingredients[0].name == 'Pasta'
    # The app ships one locale, so units are handed out in Ukrainian.
    assert recipe.ingredients[0].unit == 'г'
    assert recipe.nutrition.calories == 450
    assert recipe.content_kind == 'process'


@pytest.mark.parametrize('kind', ['technique', 'process'])
def test_non_recipe_content_allows_empty_ingredients(kind):
    content = RecipeCreate(
        chef_id=uuid4(), title='Knife work', description='Practice safely',
        cuisine='Українська', category='other', difficulty=1,
        prep_time_minutes=0, cook_time_minutes=0, servings=1,
        content_kind=kind, ingredients=[], instructions=['Повторіть рух'],
    )
    assert content.content_kind == kind
    assert content.ingredients == []


def test_recipe_content_requires_ingredients_and_video_requires_source():
    common = dict(
        chef_id=uuid4(), title='Content', description='Body', cuisine='Українська',
        category='other', difficulty=1, prep_time_minutes=0, cook_time_minutes=0,
        servings=1, instructions=[], ingredients=[],
    )
    with pytest.raises(ValueError, match='ingredient'):
        RecipeCreate(**common)
    with pytest.raises(ValueError, match='Video content requires'):
        RecipeCreate(**common, content_kind='video')
    video = RecipeCreate(**common, content_kind='video', video_url='https://youtu.be/abc')
    assert video.content_kind == 'video'


def test_create_recipe_uses_explicit_current_user_chef_link(monkeypatch):
    owner_id = str(uuid4())
    owned_chef_id = uuid4()
    created_id = str(uuid4())
    captured = {}

    class Result:
        data = [{'id': created_id}]

    async def fake_create(payload):
        captured.update(payload)
        return Result()

    async def fake_chef_link(user_id):
        assert user_id == owner_id
        return str(owned_chef_id)

    async def fake_get(recipe_id, current_user, tenant):
        return {'id': recipe_id, 'owner': current_user.id}

    monkeypatch.setattr(recipes.supabase_service, 'create_recipe', fake_create)
    monkeypatch.setattr(recipes.supabase_service, 'get_user_chef_id', fake_chef_link)
    monkeypatch.setattr(recipes, 'get_recipe', fake_get)

    payload = RecipeCreate(
        chef_id=owned_chef_id,
        title='Pasta',
        description='Fast dinner',
        cuisine='Italian',
        category='Second Courses',
        difficulty=2,
        prep_time_minutes=5,
        cook_time_minutes=10,
        servings=2,
        instructions=['Cook'],
        ingredients=[{'name': 'Pasta', 'amount': 200, 'unit': 'g', 'order': 0}],
    )

    response = asyncio.run(
        recipes.create_recipe(
            payload,
            User(id=owner_id, email='owner@example.com', chef_id=str(owned_chef_id)),
            TenantContext(chef_id=str(owned_chef_id), slug='tenant-a'),
        )
    )

    assert captured['chef_id'] == str(owned_chef_id)
    assert captured['chef_id'] != owner_id
    UUID(captured['id'])
    assert response == {'id': created_id, 'owner': owner_id}


def test_create_recipe_fails_closed_without_user_chef_link(monkeypatch):
    payload = RecipeCreate(
        chef_id=uuid4(),
        title='Pasta',
        description='Fast dinner',
        cuisine='Italian',
        category='Second Courses',
        difficulty=2,
        prep_time_minutes=5,
        cook_time_minutes=10,
        servings=2,
        instructions=['Cook'],
        ingredients=[{'name': 'Pasta', 'amount': 200, 'unit': 'g', 'order': 0}],
    )

    async def no_chef_link(_user_id):
        return None

    monkeypatch.setattr(recipes.supabase_service, 'get_user_chef_id', no_chef_link)

    with pytest.raises(HTTPException) as error:
        asyncio.run(
            recipes.create_recipe(
                payload,
                User(id=str(uuid4()), email='user@example.com'),
                TenantContext(chef_id=str(payload.chef_id), slug='tenant-a'),
            )
        )

    assert error.value.status_code == 403


def test_set_favorite_uses_authenticated_user_and_desired_state(monkeypatch):
    user_id = str(uuid4())
    recipe_id = str(uuid4())
    calls = []

    class RecipeResult:
        data = [{'id': recipe_id}]

    async def fake_get_recipe(requested_id, _chef_id):
        assert requested_id == recipe_id
        return RecipeResult()

    async def fake_set(requested_user_id, requested_recipe_id, requested_state):
        calls.append((requested_user_id, requested_recipe_id, requested_state))
        return True

    monkeypatch.setattr(recipes.supabase_service, 'get_recipe_by_id', fake_get_recipe)
    monkeypatch.setattr(recipes.supabase_service, 'set_user_favorite', fake_set)

    response = asyncio.run(
        recipes.set_recipe_favorite(
            recipe_id,
            True,
            User(id=user_id, email='user@example.com'),
            TenantContext(chef_id=str(uuid4()), slug='tenant-a'),
        )
    )

    assert calls == [(user_id, recipe_id, True)]
    assert response == {'recipe_id': recipe_id, 'is_favorite': True}


def test_private_recipe_is_hidden_from_guests(monkeypatch):
    recipe_id = str(uuid4())

    tenant = TenantContext(chef_id=str(uuid4()), slug='tenant-a')

    async def private_recipe(_recipe_id, _chef_id):
        return {
            'data': [{
                'id': recipe_id,
                'chef_id': tenant.chef_id,
                'is_public': False,
                'is_premium': False,
            }]
        }

    monkeypatch.setattr(recipes.supabase_service, 'get_recipe_by_id', private_recipe)

    with pytest.raises(HTTPException) as error:
        asyncio.run(recipes.get_recipe(recipe_id, None, tenant))

    assert error.value.status_code == 404


class _SelectSpy:
    """Records the PostgREST select string and swallows the rest of the chain."""

    def __init__(self, recorded):
        self._recorded = recorded

    def table(self, _name):
        return self

    def select(self, columns, **_kwargs):
        self._recorded.append(columns)
        return self

    def __getattr__(self, _name):
        return lambda *args, **kwargs: self

    def execute(self):
        return type('Result', (), {'data': []})()


@pytest.mark.parametrize('read', [
    lambda: supabase_service.get_recipes({'is_public': True}, 5, 0),
    lambda: supabase_service.get_recipe_by_id(str(uuid4()), str(uuid4())),
    lambda: supabase_service.search_recipes_by_text('soup', str(uuid4())),
])
def test_recipe_reads_embed_ingredients_in_a_single_line_select(monkeypatch, read):
    """PostgREST drops a select that starts with a newline.

    It answers 200 with the bare recipe columns and no embedded
    `recipe_ingredients`, so an indented multi-line select empties every
    ingredient list in the app without raising anything.
    """
    recorded = []
    monkeypatch.setattr(
        supabase_service, 'get_client', lambda *a, **k: _SelectSpy(recorded)
    )

    asyncio.run(read())

    assert len(recorded) == 1
    select = recorded[0]
    assert 'recipe_ingredients(*)' in select
    assert select == select.strip()
    assert '\n' not in select
