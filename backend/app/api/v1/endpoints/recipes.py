from fastapi import APIRouter, HTTPException, Depends, Query, status
from typing import Optional, List, Dict, Any
from uuid import UUID, uuid4
import logging

from app.schemas.recipe import Recipe, RecipeList, RecipeFilters, RecipeCreate
from app.schemas.chef import ChefConfig
from app.services.database import supabase_service
from app.api.v1.endpoints.auth import get_optional_user, verify_firebase_token, User
from app.core.premium_access import filter_recipes_by_subscription, check_recipe_access
from app.services.subscription_service import subscription_service
from app.core.tenant import TenantContext, require_tenant_context
from app.core.content_access import resolve_recipe_access

router = APIRouter()
logger = logging.getLogger(__name__)

_CATEGORY_IDS = {
    'appetizers': '20000000-0000-0000-0000-000000000001',
    'first courses': '20000000-0000-0000-0000-000000000002',
    'second courses': '20000000-0000-0000-0000-000000000003',
    'side dishes': '20000000-0000-0000-0000-000000000004',
    'desserts': '20000000-0000-0000-0000-000000000005',
    'beverages': '20000000-0000-0000-0000-000000000006',
    'bread & baked goods': '20000000-0000-0000-0000-000000000007',
    'salads': '20000000-0000-0000-0000-000000000008',
    'other': '20000000-0000-0000-0000-000000000099',
}

_UNIT_IDS = {
    'g': '00000000-0000-0000-0000-000000000001',
    'kg': '00000000-0000-0000-0000-000000000002',
    'ml': '00000000-0000-0000-0000-000000000010',
    'l': '00000000-0000-0000-0000-000000000011',
    'piece': '00000000-0000-0000-0000-000000000020',
    'cup': '00000000-0000-0000-0000-000000000021',
    'tbsp': '00000000-0000-0000-0000-000000000031',
    'tsp': '00000000-0000-0000-0000-000000000032',
    'oz': '00000000-0000-0000-0000-000000000041',
    'lb': '00000000-0000-0000-0000-000000000051',
}


def _result_data(result: Any) -> list:
    if isinstance(result, dict):
        return result.get('data') or []
    return getattr(result, 'data', None) or []


async def _owned_chef_id(current_user: User) -> str:
    """Return the explicitly linked chef, failing closed when no link exists."""
    chef_id = await supabase_service.get_user_chef_id(current_user.id)
    if not chef_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account is not linked to a chef profile",
        )
    return chef_id


def _category_id(value: Optional[str]) -> str:
    if value:
        try:
            return str(UUID(value))
        except ValueError:
            pass
    return _CATEGORY_IDS.get((value or 'other').strip().lower(), _CATEGORY_IDS['other'])


def _recipe_payload_to_rows(payload: Dict[str, Any], *, partial: bool = False) -> Dict[str, Any]:
    """Translate the public recipe contract to the canonical SQL schema."""
    rows: Dict[str, Any] = {}

    direct_fields = (
        'title', 'description', 'prep_time_minutes', 'cook_time_minutes',
        'servings', 'video_url', 'video_file_path', 'is_featured',
    )
    for field in direct_fields:
        if field in payload:
            rows[field] = payload[field]

    if 'difficulty' in payload:
        rows['difficulty_level'] = payload['difficulty']
    if 'category' in payload:
        rows['category_id'] = _category_id(payload.get('category'))
    elif not partial:
        rows['category_id'] = _CATEGORY_IDS['other']

    if 'instructions' in payload:
        instructions = _normalize_instructions(payload.get('instructions'))
        rows['instructions'] = '\n'.join(instructions)
        rows['instructions_structured'] = instructions

    if 'images' in payload:
        images = _normalize_images(payload.get('images'))
        rows['image_url'] = images[0] if images else None

    if 'tags' in payload or 'cuisine' in payload:
        tags = list(payload.get('tags') or [])
        cuisine = payload.get('cuisine')
        if cuisine and not any(str(tag).lower() == str(cuisine).lower() for tag in tags):
            tags.append(cuisine)
        rows['tags'] = tags

    if 'ingredients' in payload:
        ingredients = []
        for index, ingredient in enumerate(payload.get('ingredients') or []):
            amount = ingredient.get('amount')
            unit = str(ingredient.get('unit') or '').strip().lower()
            ingredients.append({
                'display_name': ingredient.get('name') or ingredient.get('display_name'),
                # Canonical schema requires positive amounts; null represents "to taste".
                'amount': amount if amount is not None and float(amount) > 0 else None,
                'unit_id': _UNIT_IDS.get(unit),
                'preparation_notes': ingredient.get('notes') or ingredient.get('preparation_notes'),
                'sort_order': ingredient.get('order', ingredient.get('sort_order', index)),
            })
        rows['ingredients'] = ingredients

    if 'nutrition' in payload:
        nutrition = payload.get('nutrition')
        rows['nutrition'] = None if nutrition is None else {
            'calories_per_serving': nutrition.get('calories'),
            'protein_g_per_serving': nutrition.get('protein_g'),
            'carbs_g_per_serving': nutrition.get('carbs_g'),
            'fat_g_per_serving': nutrition.get('fat_g'),
            'fiber_g_per_serving': nutrition.get('fiber_g'),
            'sugar_g_per_serving': nutrition.get('sugar_g'),
            'sodium_mg_per_serving': nutrition.get('sodium_mg'),
        }

    return rows


def _get_unit_name_from_id(unit_id: str) -> str:
    """Convert unit_id to unit name"""
    if not unit_id:
        return 'од.'

    # Simple unit mapping - in production you'd query the units table
    unit_mapping = {
        '00000000-0000-0000-0000-000000000001': 'g',
        '00000000-0000-0000-0000-000000000010': 'ml',
        '00000000-0000-0000-0000-000000000020': 'шт',
        '00000000-0000-0000-0000-000000000031': 'tbsp',
        '00000000-0000-0000-0000-000000000032': 'tsp',
        '00000000-0000-0000-0000-000000000002': 'kg',
        '00000000-0000-0000-0000-000000000011': 'l',
        '00000000-0000-0000-0000-000000000021': 'cup',
        '00000000-0000-0000-0000-000000000041': 'oz',
        '00000000-0000-0000-0000-000000000051': 'lb'
    }
    return unit_mapping.get(unit_id, 'од.')


def _get_category_name_from_id(category_id: str) -> str:
    """Convert category_id to category name"""
    if not category_id:
        return 'Інше'

    # Category mapping based on database
    category_mapping = {
        '20000000-0000-0000-0000-000000000001': 'Закуски',
        '20000000-0000-0000-0000-000000000002': 'Перші страви',
        '20000000-0000-0000-0000-000000000003': 'Другі страви',
        '20000000-0000-0000-0000-000000000004': 'Гарніри',
        '20000000-0000-0000-0000-000000000005': 'Десерти',
        '20000000-0000-0000-0000-000000000006': 'Напої',
        '20000000-0000-0000-0000-000000000007': 'Хліб і випічка',
        '20000000-0000-0000-0000-000000000008': 'Салати',
        '20000000-0000-0000-0000-000000000099': 'Інше'
    }
    return category_mapping.get(category_id, 'Інше')


def _extract_cuisine_from_tags(tags: list) -> str:
    """Extract cuisine from tags"""
    if not tags:
        return 'Інше'

    # Common cuisines to look for in tags
    cuisines = [
        'Italian', 'Mexican', 'Chinese', 'Indian', 'French', 'Thai', 'Japanese',
        'Mediterranean', 'American', 'Greek', 'Spanish', 'Korean', 'Vietnamese',
        'Middle Eastern', 'British', 'German', 'Russian', 'Turkish', 'Lebanese',
        'Moroccan', 'Ethiopian', 'Brazilian', 'Argentinian', 'Peruvian', 'Caribbean'
    ]

    # Look for cuisine in tags (case insensitive)
    for tag in tags:
        for cuisine in cuisines:
            if tag.lower() == cuisine.lower():
                return cuisine

    return 'Інше'

def _normalize_instructions(instructions_data):
    """Normalize instructions data to List[str]"""
    if isinstance(instructions_data, list):
        return [str(inst) for inst in instructions_data if inst]
    elif isinstance(instructions_data, str):
        # If it's a single string, split by newlines or return as single item
        if '\n' in instructions_data:
            return [line.strip() for line in instructions_data.split('\n') if line.strip()]
        else:
            return [instructions_data]
    else:
        return ["Інструкції не вказані"]

def _normalize_images(images_data):
    """Normalize images data to List[str]"""
    if isinstance(images_data, list):
        return [str(img) for img in images_data if img]
    elif isinstance(images_data, str) and images_data:
        return [images_data]
    else:
        return []

def _normalize_video_url(video_url_data):
    """Normalize video URL data"""
    if isinstance(video_url_data, str) and video_url_data.strip():
        return video_url_data.strip()
    return None

def _normalize_video_file_path(video_file_path_data):
    """Normalize video file path data"""
    if isinstance(video_file_path_data, str) and video_file_path_data.strip():
        return video_file_path_data.strip()
    return None


def _recipe_from_row(recipe_data: Dict[str, Any]) -> Recipe:
    """Build the public Recipe model from a canonical database row."""
    row = dict(recipe_data)
    ingredient_rows = row.pop('recipe_ingredients', []) or []
    nutrition_rows = row.pop('recipe_nutrition', []) or []
    if isinstance(nutrition_rows, dict):
        nutrition_rows = [nutrition_rows]

    ingredients = []
    for ingredient_data in ingredient_rows:
        ingredients.append({
            'id': ingredient_data['id'],
            'recipe_id': ingredient_data.get('recipe_id', row['id']),
            'name': ingredient_data.get('display_name', ''),
            'amount': float(ingredient_data.get('amount') or 0),
            'unit': _get_unit_name_from_id(ingredient_data.get('unit_id'))
                if ingredient_data.get('unit_id') else 'unit',
            'notes': ingredient_data.get('preparation_notes'),
            'order': ingredient_data.get('sort_order', 0),
        })

    nutrition = None
    if nutrition_rows:
        nutrition_row = nutrition_rows[0]
        nutrition = {
            'id': nutrition_row['id'],
            'recipe_id': nutrition_row.get('recipe_id', row['id']),
            'calories': nutrition_row.get('calories_per_serving'),
            'protein_g': nutrition_row.get('protein_g_per_serving'),
            'carbs_g': nutrition_row.get('carbs_g_per_serving'),
            'fat_g': nutrition_row.get('fat_g_per_serving'),
            'fiber_g': nutrition_row.get('fiber_g_per_serving'),
            'sugar_g': nutrition_row.get('sugar_g_per_serving'),
            'sodium_mg': nutrition_row.get('sodium_mg_per_serving'),
        }

    instructions = row.get('instructions_structured') or row.get('instructions', [])
    return Recipe(**{
        'id': row['id'],
        'chef_id': row['chef_id'],
        'title': row.get('title', ''),
        'description': row.get('description') or '',
        'cuisine': _extract_cuisine_from_tags(row.get('tags', [])),
        'category': _get_category_name_from_id(row.get('category_id')),
        'difficulty': row.get('difficulty_level', 1),
        'prep_time_minutes': row.get('prep_time_minutes') or 0,
        'cook_time_minutes': row.get('cook_time_minutes') or 0,
        'total_time_minutes': row.get('total_time_minutes') or 0,
        'servings': row.get('servings') or 1,
        'instructions': _normalize_instructions(instructions),
        'images': _normalize_images(row.get('image_url')),
        'video_url': _normalize_video_url(row.get('video_url')),
        'video_file_path': _normalize_video_file_path(row.get('video_file_path')),
        'tags': row.get('tags', []),
        'is_featured': row.get('is_featured', False),
        'is_premium': row.get('is_premium', False),
        'created_at': row.get('created_at'),
        'updated_at': row.get('updated_at'),
        'ingredients': ingredients,
        'nutrition': nutrition,
    })


def _premium_teaser(recipe_data: Dict[str, Any]) -> Recipe:
    """Project list/detail metadata without ingredients, steps or video URLs."""
    teaser = _recipe_from_row({
        **recipe_data,
        'recipe_ingredients': [],
        'recipe_nutrition': [],
        'instructions': [],
        'instructions_structured': [],
        'video_url': None,
        'video_file_path': None,
    })
    return teaser.model_copy(update={'is_locked': True})

@router.get("/", response_model=RecipeList)
async def get_recipes(
    cuisine: Optional[str] = Query(None, description="Filter by cuisine type"),
    difficulty: Optional[int] = Query(None, ge=1, le=5, description="Filter by difficulty (1-5)"),
    max_time: Optional[int] = Query(None, ge=0, description="Maximum total time in minutes"),
    category: Optional[str] = Query(None, description="Filter by category"),
    tags: Optional[List[str]] = Query(None, description="Filter by tags"),
    is_featured: Optional[bool] = Query(None, description="Filter featured recipes"),
    limit: int = Query(20, ge=1, le=100, description="Number of recipes to return"),
    offset: int = Query(0, ge=0, description="Number of recipes to skip"),
    current_user: Optional[User] = Depends(get_optional_user),
    tenant: TenantContext = Depends(require_tenant_context),
):
    """Get recipes with optional filtering (respects user subscription tier)"""
    logger.info(
        "GET /recipes/ called by %s",
        current_user.id if current_user else "guest",
    )
    try:
        # Build filters dictionary
        filters = {'is_public': True}
        if cuisine:
            filters['tags_contains'] = [cuisine]
        if difficulty:
            filters['difficulty_level'] = difficulty
        if max_time:
            filters['max_time'] = max_time
        if category:
            filters['category_id'] = _category_id(category)
        filters['chef_id'] = tenant.chef_id
        if is_featured is not None:
            filters['is_featured'] = is_featured
        if tags:
            filters['tags_contains'] = tags

        # Get recipes from database
        logger.info(f"🔍 Fetching recipes with filters: {filters}")
        result = await supabase_service.get_recipes(filters, limit, offset)
        logger.info(f"📦 Got {len(result.data) if result.data else 0} recipes from database")

        if not result.data:
            logger.info("📭 No recipes found, returning empty list")
            return RecipeList(recipes=[], total_count=0, has_more=False)
        
        recipes = []
        for recipe_data in result.data:
            try:
                access = await resolve_recipe_access(recipe_data, tenant, current_user)
                if not access.exists_in_tenant:
                    continue
                if not access.can_read_body:
                    recipes.append(_premium_teaser(recipe_data))
                    continue
                # Ingredients are now included via JOIN, no need for separate query
                recipe_ingredients = recipe_data.pop('recipe_ingredients', [])

                # Convert string UUIDs to UUID objects
                if isinstance(recipe_data.get('id'), str):
                    recipe_data['id'] = UUID(recipe_data['id'])
                if isinstance(recipe_data.get('chef_id'), str):
                    recipe_data['chef_id'] = UUID(recipe_data['chef_id'])

                # Handle field name mapping and data type conversion
                normalized_data = {
                    'id': recipe_data['id'],
                    'chef_id': recipe_data['chef_id'],
                    'title': recipe_data.get('title', ''),
                    'description': recipe_data.get('description', ''),
                    'cuisine': _extract_cuisine_from_tags(recipe_data.get('tags', [])),
                    'category': _get_category_name_from_id(recipe_data.get('category_id')),
                    'difficulty': recipe_data.get('difficulty', recipe_data.get('difficulty_level', 1)),
                    'prep_time_minutes': recipe_data.get('prep_time_minutes', 0),
                    'cook_time_minutes': recipe_data.get('cook_time_minutes', 0),
                    'total_time_minutes': recipe_data.get('total_time_minutes',
                        recipe_data.get('prep_time_minutes', 0) + recipe_data.get('cook_time_minutes', 0)),
                    'servings': recipe_data.get('servings', 1),
                    'instructions': _normalize_instructions(recipe_data.get('instructions', [])),
                    'images': _normalize_images(recipe_data.get('images', recipe_data.get('image_url'))),
                    'video_url': _normalize_video_url(recipe_data.get('video_url')),
                    'video_file_path': _normalize_video_file_path(recipe_data.get('video_file_path')),
                    'tags': recipe_data.get('tags', []),
                    'is_featured': recipe_data.get('is_featured', False),
                    'is_premium': recipe_data.get('is_premium', False),
                    'created_at': recipe_data.get('created_at'),
                    'updated_at': recipe_data.get('updated_at'),
                    'ingredients': []  # Will be populated below
                }

                # Convert ingredients
                for ingredient_data in recipe_ingredients:
                    try:
                        if isinstance(ingredient_data.get('id'), str):
                            ingredient_data['id'] = UUID(ingredient_data['id'])
                        if isinstance(ingredient_data.get('recipe_id'), str):
                            ingredient_data['recipe_id'] = UUID(ingredient_data['recipe_id'])

                        # Map ingredient fields
                        ingredient = {
                            'id': ingredient_data['id'],
                            'recipe_id': ingredient_data['recipe_id'],
                            'name': ingredient_data.get('display_name', ingredient_data.get('name', '')),
                            'amount': float(ingredient_data.get('amount', 0)) if ingredient_data.get('amount') is not None else 0,
                            'unit': _get_unit_name_from_id(ingredient_data.get('unit_id')) if ingredient_data.get('unit_id') else ingredient_data.get('unit', 'unit'),
                            'notes': ingredient_data.get('preparation_notes', ingredient_data.get('notes')),
                            'order': ingredient_data.get('sort_order', ingredient_data.get('order', 0))
                        }
                        normalized_data['ingredients'].append(ingredient)
                    except Exception as e:
                        logger.warning(f"Error converting ingredient: {str(e)}")
                        continue

                # Convert to Recipe model
                recipe = Recipe(**normalized_data)
                recipes.append(recipe)
            except Exception as e:
                logger.error(f"Error converting recipe data to model: {str(e)}")
                logger.error(f"Recipe data: {recipe_data}")
                # Skip this recipe and continue with others
                continue

        # Calculate total count and has_more
        total_count = len(recipes)
        has_more = len(result.data) == limit

        logger.info(f"🎉 Returning {len(recipes)} recipes to client")
        return RecipeList(
            recipes=recipes,
            total_count=total_count,
            has_more=has_more
        )

    except Exception as e:
        logger.error(f"❌ Error fetching recipes: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch recipes"
        )

@router.get("/featured", response_model=List[Recipe])
async def get_featured_recipes(
    limit: int = Query(10, ge=1, le=50, description="Number of featured recipes to return"),
    current_user: Optional[User] = Depends(get_optional_user),
    tenant: TenantContext = Depends(require_tenant_context),
):
    """Get featured recipes"""
    try:
        filters = {'is_featured': True, 'is_public': True}
        filters['chef_id'] = tenant.chef_id
            
        result = await supabase_service.get_recipes(filters, limit, 0)
        
        if not result.data:
            return []
        
        recipes = []
        for recipe_data in result.data:
            try:
                access = await resolve_recipe_access(recipe_data, tenant, current_user)
                if not access.exists_in_tenant:
                    continue
                if not access.can_read_body:
                    recipes.append(_premium_teaser(recipe_data))
                    continue
                # Get ingredients for each recipe
                ingredients_result = await supabase_service.get_recipe_ingredients(recipe_data['id'])
                recipe_ingredients = ingredients_result.get('data', [])

                # Convert string UUIDs to UUID objects
                if isinstance(recipe_data.get('id'), str):
                    recipe_data['id'] = UUID(recipe_data['id'])
                if isinstance(recipe_data.get('chef_id'), str):
                    recipe_data['chef_id'] = UUID(recipe_data['chef_id'])

                # Handle field name mapping and data type conversion
                normalized_data = {
                    'id': recipe_data['id'],
                    'chef_id': recipe_data['chef_id'],
                    'title': recipe_data.get('title', ''),
                    'description': recipe_data.get('description', ''),
                    'cuisine': _extract_cuisine_from_tags(recipe_data.get('tags', [])),
                    'category': _get_category_name_from_id(recipe_data.get('category_id')),
                    'difficulty': recipe_data.get('difficulty', recipe_data.get('difficulty_level', 1)),
                    'prep_time_minutes': recipe_data.get('prep_time_minutes', 0),
                    'cook_time_minutes': recipe_data.get('cook_time_minutes', 0),
                    'total_time_minutes': recipe_data.get('total_time_minutes',
                        recipe_data.get('prep_time_minutes', 0) + recipe_data.get('cook_time_minutes', 0)),
                    'servings': recipe_data.get('servings', 1),
                    'instructions': _normalize_instructions(recipe_data.get('instructions', [])),
                    'images': _normalize_images(recipe_data.get('images', recipe_data.get('image_url'))),
                    'video_url': _normalize_video_url(recipe_data.get('video_url')),
                    'video_file_path': _normalize_video_file_path(recipe_data.get('video_file_path')),
                    'tags': recipe_data.get('tags', []),
                    'is_featured': recipe_data.get('is_featured', False),
                    'is_premium': recipe_data.get('is_premium', False),
                    'created_at': recipe_data.get('created_at'),
                    'updated_at': recipe_data.get('updated_at'),
                    'ingredients': []  # Will be populated below
                }

                # Convert ingredients
                for ingredient_data in recipe_ingredients:
                    try:
                        if isinstance(ingredient_data.get('id'), str):
                            ingredient_data['id'] = UUID(ingredient_data['id'])
                        if isinstance(ingredient_data.get('recipe_id'), str):
                            ingredient_data['recipe_id'] = UUID(ingredient_data['recipe_id'])

                        # Map ingredient fields
                        ingredient = {
                            'id': ingredient_data['id'],
                            'recipe_id': ingredient_data['recipe_id'],
                            'name': ingredient_data.get('display_name', ingredient_data.get('name', '')),
                            'amount': float(ingredient_data.get('amount', 0)) if ingredient_data.get('amount') is not None else 0,
                            'unit': _get_unit_name_from_id(ingredient_data.get('unit_id')) if ingredient_data.get('unit_id') else ingredient_data.get('unit', 'unit'),
                            'notes': ingredient_data.get('preparation_notes', ingredient_data.get('notes')),
                            'order': ingredient_data.get('sort_order', ingredient_data.get('order', 0))
                        }
                        normalized_data['ingredients'].append(ingredient)
                    except Exception as e:
                        logger.warning(f"Error converting ingredient: {str(e)}")
                        continue

                recipe = Recipe(**normalized_data)
                recipes.append(recipe)
            except Exception as e:
                logger.error(f"Error converting featured recipe data to model: {str(e)}")
                logger.error(f"Recipe data: {recipe_data}")
                # Skip this recipe and continue with others
                continue
        
        return recipes
        
    except Exception as e:
        logger.error(f"Error fetching featured recipes: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch featured recipes"
        )

@router.get("/favorites", response_model=List[Recipe])
async def get_favorite_recipes(
    current_user: User = Depends(verify_firebase_token),
    tenant: TenantContext = Depends(require_tenant_context),
):
    """Return the authenticated user's saved recipes."""
    favorite_ids = await supabase_service.get_user_favorite_ids(current_user.id)
    if not favorite_ids:
        return []
    result = await supabase_service.get_recipes(
        {'id': favorite_ids, 'chef_id': tenant.chef_id}, min(len(favorite_ids), 100), 0,
    )
    return [_recipe_from_row(row) for row in _result_data(result)]


@router.put("/{recipe_id}/favorite")
async def set_recipe_favorite(
    recipe_id: str,
    is_favorite: bool,
    current_user: User = Depends(verify_firebase_token),
    tenant: TenantContext = Depends(require_tenant_context),
):
    """Persist the requested saved state for a recipe in this tenant."""
    try:
        UUID(recipe_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid recipe ID format")

    if not _result_data(await supabase_service.get_recipe_by_id(recipe_id, tenant.chef_id)):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")

    is_favorite = await supabase_service.set_user_favorite(
        current_user.id, recipe_id, is_favorite
    )
    return {'recipe_id': recipe_id, 'is_favorite': is_favorite}


@router.post("/{recipe_id}/history/{event}", status_code=status.HTTP_204_NO_CONTENT)
async def record_recipe_history(
    recipe_id: str,
    event: str,
    current_user: User = Depends(verify_firebase_token),
    tenant: TenantContext = Depends(require_tenant_context),
):
    """Record a viewed/cooked event without exposing another tenant's history."""
    if event not in {'viewed', 'cooked'}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid history event")
    try:
        UUID(recipe_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid recipe ID format")
    if not _result_data(await supabase_service.get_recipe_by_id(recipe_id, tenant.chef_id)):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")
    await supabase_service.record_recipe_history(current_user.id, tenant.chef_id, recipe_id, event)


@router.get("/{recipe_id}", response_model=Recipe)
async def get_recipe(
    recipe_id: str,
    current_user: Optional[User] = Depends(get_optional_user),
    tenant: TenantContext = Depends(require_tenant_context),
):
    """Get a single recipe by ID (checks premium access for premium recipes)"""
    try:
        # Validate UUID format
        try:
            UUID(recipe_id)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid recipe ID format"
            )

        result = await supabase_service.get_recipe_by_id(recipe_id, tenant.chef_id)

        if not _result_data(result):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Recipe not found"
            )

        recipe_data = _result_data(result)[0]

        access = await resolve_recipe_access(recipe_data, tenant, current_user)
        if not access.exists_in_tenant:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Recipe not found",
            )

        return _recipe_from_row(recipe_data) if access.can_read_body else _premium_teaser(recipe_data)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching recipe {recipe_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch recipe"
        )

@router.post("/", response_model=Recipe, status_code=status.HTTP_201_CREATED)
async def create_recipe(
    recipe_data: RecipeCreate,
    current_user: User = Depends(verify_firebase_token),
    tenant: TenantContext = Depends(require_tenant_context),
):
    """Create a new recipe (authenticated users only)"""
    try:
        # Convert Pydantic model to dict
        owned_chef_id = await _owned_chef_id(current_user)
        if owned_chef_id != tenant.chef_id or str(recipe_data.chef_id) != tenant.chef_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cannot create recipes for another chef",
            )
        public_payload = recipe_data.model_dump()
        recipe_dict = _recipe_payload_to_rows(public_payload)
        recipe_dict['id'] = str(uuid4())
        recipe_dict['chef_id'] = owned_chef_id
        
        result = await supabase_service.create_recipe(recipe_dict)
        
        if not _result_data(result):
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create recipe"
            )
        
        # Return the created recipe
        created_recipe_id = _result_data(result)[0]['id']
        return await get_recipe(created_recipe_id, current_user, tenant)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating recipe: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create recipe"
        )


@router.put("/{recipe_id}", response_model=Recipe)
async def update_recipe(
    recipe_id: str,
    recipe_data: Dict[str, Any],
    current_user: User = Depends(verify_firebase_token),
    tenant: TenantContext = Depends(require_tenant_context),
):
    """Update an owned recipe using the frontend's recipe JSON contract."""
    try:
        UUID(recipe_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid recipe ID format")

    owned_chef_id = await _owned_chef_id(current_user)
    if owned_chef_id != tenant.chef_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Cannot modify another tenant")
    update_rows = _recipe_payload_to_rows(recipe_data, partial=True)
    if not update_rows:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="No supported fields supplied")
    result = await supabase_service.update_owned_recipe(recipe_id, owned_chef_id, update_rows)
    if not _result_data(result):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")
    return await get_recipe(recipe_id, current_user, tenant)


@router.delete("/{recipe_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_recipe(
    recipe_id: str,
    current_user: User = Depends(verify_firebase_token),
    tenant: TenantContext = Depends(require_tenant_context),
):
    """Delete an owned recipe."""
    try:
        UUID(recipe_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid recipe ID format")
    owned_chef_id = await _owned_chef_id(current_user)
    if owned_chef_id != tenant.chef_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Cannot modify another tenant")
    result = await supabase_service.delete_owned_recipe(recipe_id, owned_chef_id)
    if not _result_data(result):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")

@router.get("/chef/{chef_id}/config", response_model=ChefConfig)
async def get_chef_config(chef_id: str):
    """Get chef configuration for white-label customization"""
    try:
        # Validate UUID format
        try:
            UUID(chef_id)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid chef ID format"
            )
        
        result = await supabase_service.get_chef_config(chef_id)
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Chef configuration not found"
            )
        
        chef_data = result.data[0]
        
        # Convert to ChefConfig format
        config = ChefConfig(
            chef_id=chef_data['id'],
            name=chef_data['name'],
            app_name=chef_data['app_name'],
            avatar_url=chef_data.get('avatar_url'),
            logo_url=chef_data.get('logo_url'),
            theme=chef_data['theme_config'],
            social_links=chef_data.get('social_links')
        )
        
        return config
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching chef config {chef_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch chef configuration"
        )
