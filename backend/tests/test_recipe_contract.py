import asyncio
from datetime import datetime, timezone
from uuid import UUID, uuid4

import pytest

from app.api.v1.endpoints import recipes
from fastapi import HTTPException

from app.api.v1.endpoints.auth import User
from app.schemas.recipe import RecipeCreate


def test_public_payload_maps_to_canonical_recipe_tables():
    rows = recipes._recipe_payload_to_rows({
        'title': 'Pasta',
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
    assert recipe.ingredients[0].name == 'Pasta'
    assert recipe.ingredients[0].unit == 'g'
    assert recipe.nutrition.calories == 450


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

    async def fake_get(recipe_id, current_user):
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
            )
        )

    assert error.value.status_code == 403


def test_toggle_favorite_uses_authenticated_user(monkeypatch):
    user_id = str(uuid4())
    recipe_id = str(uuid4())
    calls = []

    class RecipeResult:
        data = [{'id': recipe_id}]

    async def fake_get_recipe(requested_id):
        assert requested_id == recipe_id
        return RecipeResult()

    async def fake_toggle(requested_user_id, requested_recipe_id):
        calls.append((requested_user_id, requested_recipe_id))
        return True

    monkeypatch.setattr(recipes.supabase_service, 'get_recipe_by_id', fake_get_recipe)
    monkeypatch.setattr(recipes.supabase_service, 'toggle_user_favorite', fake_toggle)

    response = asyncio.run(
        recipes.toggle_recipe_favorite(
            recipe_id,
            User(id=user_id, email='user@example.com'),
        )
    )

    assert calls == [(user_id, recipe_id)]
    assert response == {'recipe_id': recipe_id, 'is_favorite': True}


def test_private_recipe_is_hidden_from_guests(monkeypatch):
    recipe_id = str(uuid4())

    async def private_recipe(_recipe_id):
        return {
            'data': [{
                'id': recipe_id,
                'chef_id': str(uuid4()),
                'is_public': False,
                'is_premium': False,
            }]
        }

    monkeypatch.setattr(recipes.supabase_service, 'get_recipe_by_id', private_recipe)

    with pytest.raises(HTTPException) as error:
        asyncio.run(recipes.get_recipe(recipe_id, None))

    assert error.value.status_code == 404
