from fastapi import APIRouter, HTTPException, Depends, Query, status
from typing import Optional, List
from uuid import UUID
import logging

from app.schemas.recipe import Recipe, RecipeList, RecipeFilters, RecipeCreate
from app.schemas.chef import ChefConfig
from app.services.database import supabase_service
from app.api.v1.endpoints.auth import verify_firebase_token, User

router = APIRouter()
logger = logging.getLogger(__name__)


def _get_unit_name_from_id(unit_id: str) -> str:
    """Convert unit_id to unit name"""
    if not unit_id:
        return 'unit'

    # Simple unit mapping - in production you'd query the units table
    unit_mapping = {
        '00000000-0000-0000-0000-000000000001': 'g',
        '00000000-0000-0000-0000-000000000010': 'ml',
        '00000000-0000-0000-0000-000000000020': 'piece',
        '00000000-0000-0000-0000-000000000031': 'tbsp',
        '00000000-0000-0000-0000-000000000032': 'tsp',
        '00000000-0000-0000-0000-000000000002': 'kg',
        '00000000-0000-0000-0000-000000000011': 'l',
        '00000000-0000-0000-0000-000000000021': 'cup',
        '00000000-0000-0000-0000-000000000041': 'oz',
        '00000000-0000-0000-0000-000000000051': 'lb'
    }
    return unit_mapping.get(unit_id, 'unit')

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
        return ["No instructions provided"]

def _normalize_images(images_data):
    """Normalize images data to List[str]"""
    if isinstance(images_data, list):
        return [str(img) for img in images_data if img]
    elif isinstance(images_data, str) and images_data:
        return [images_data]
    else:
        return []

@router.get("/", response_model=RecipeList)
async def get_recipes(
    cuisine: Optional[str] = Query(None, description="Filter by cuisine type"),
    difficulty: Optional[int] = Query(None, ge=1, le=5, description="Filter by difficulty (1-5)"),
    max_time: Optional[int] = Query(None, ge=0, description="Maximum total time in minutes"),
    category: Optional[str] = Query(None, description="Filter by category"),
    chef_id: Optional[str] = Query(None, description="Filter by chef ID"),
    tags: Optional[List[str]] = Query(None, description="Filter by tags"),
    is_featured: Optional[bool] = Query(None, description="Filter featured recipes"),
    limit: int = Query(20, ge=1, le=100, description="Number of recipes to return"),
    offset: int = Query(0, ge=0, description="Number of recipes to skip")
):
    """Get recipes with optional filtering"""
    try:
        # Build filters dictionary
        filters = {}
        if cuisine:
            filters['cuisine'] = cuisine
        if difficulty:
            filters['difficulty'] = difficulty
        if max_time:
            filters['max_time'] = max_time
        if category:
            filters['category'] = category
        if chef_id:
            filters['chef_id'] = chef_id
        if is_featured is not None:
            filters['is_featured'] = is_featured
        
        # Get recipes from database
        result = await supabase_service.get_recipes(filters, limit, offset)
        
        if not result.data:
            return RecipeList(recipes=[], total_count=0, has_more=False)
        
        recipes = []
        for recipe_data in result.data:
            try:
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
                    'cuisine': recipe_data.get('cuisine', 'Unknown'),
                    'category': recipe_data.get('category', 'Unknown'),
                    'difficulty': recipe_data.get('difficulty', recipe_data.get('difficulty_level', 1)),
                    'prep_time_minutes': recipe_data.get('prep_time_minutes', 0),
                    'cook_time_minutes': recipe_data.get('cook_time_minutes', 0),
                    'total_time_minutes': recipe_data.get('total_time_minutes',
                        recipe_data.get('prep_time_minutes', 0) + recipe_data.get('cook_time_minutes', 0)),
                    'servings': recipe_data.get('servings', 1),
                    'instructions': _normalize_instructions(recipe_data.get('instructions', [])),
                    'images': _normalize_images(recipe_data.get('images', recipe_data.get('image_url'))),
                    'tags': recipe_data.get('tags', []),
                    'is_featured': recipe_data.get('is_featured', False),
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
        total_count = len(result.data)
        has_more = len(result.data) == limit
        
        return RecipeList(
            recipes=recipes,
            total_count=total_count,
            has_more=has_more
        )
        
    except Exception as e:
        logger.error(f"Error fetching recipes: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch recipes"
        )

@router.get("/featured", response_model=List[Recipe])
async def get_featured_recipes(
    chef_id: Optional[str] = Query(None, description="Filter by chef ID"),
    limit: int = Query(10, ge=1, le=50, description="Number of featured recipes to return")
):
    """Get featured recipes"""
    try:
        filters = {'is_featured': True}
        if chef_id:
            filters['chef_id'] = chef_id
            
        result = await supabase_service.get_recipes(filters, limit, 0)
        
        if not result.data:
            return []
        
        recipes = []
        for recipe_data in result.data:
            try:
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
                    'cuisine': recipe_data.get('cuisine', 'Unknown'),
                    'category': recipe_data.get('category', 'Unknown'),
                    'difficulty': recipe_data.get('difficulty', recipe_data.get('difficulty_level', 1)),
                    'prep_time_minutes': recipe_data.get('prep_time_minutes', 0),
                    'cook_time_minutes': recipe_data.get('cook_time_minutes', 0),
                    'total_time_minutes': recipe_data.get('total_time_minutes',
                        recipe_data.get('prep_time_minutes', 0) + recipe_data.get('cook_time_minutes', 0)),
                    'servings': recipe_data.get('servings', 1),
                    'instructions': _normalize_instructions(recipe_data.get('instructions', [])),
                    'images': _normalize_images(recipe_data.get('images', recipe_data.get('image_url'))),
                    'tags': recipe_data.get('tags', []),
                    'is_featured': recipe_data.get('is_featured', False),
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

@router.get("/{recipe_id}", response_model=Recipe)
async def get_recipe(recipe_id: str):
    """Get a single recipe by ID"""
    try:
        # Validate UUID format
        try:
            UUID(recipe_id)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid recipe ID format"
            )

        result = await supabase_service.get_recipe_by_id(recipe_id)

        if not result.get('data'):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Recipe not found"
            )

        recipe_data = result['data'][0]

        # Get ingredients for this recipe
        ingredients_result = await supabase_service.get_recipe_ingredients(recipe_id)
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
            'cuisine': recipe_data.get('cuisine', 'Unknown'),
            'category': recipe_data.get('category', 'Unknown'),
            'difficulty': recipe_data.get('difficulty', recipe_data.get('difficulty_level', 1)),
            'prep_time_minutes': recipe_data.get('prep_time_minutes', 0),
            'cook_time_minutes': recipe_data.get('cook_time_minutes', 0),
            'total_time_minutes': recipe_data.get('total_time_minutes',
                recipe_data.get('prep_time_minutes', 0) + recipe_data.get('cook_time_minutes', 0)),
            'servings': recipe_data.get('servings', 1),
            'instructions': _normalize_instructions(recipe_data.get('instructions', [])),
            'images': _normalize_images(recipe_data.get('images', recipe_data.get('image_url'))),
            'tags': recipe_data.get('tags', []),
            'is_featured': recipe_data.get('is_featured', False),
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
        return recipe
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching recipe {recipe_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch recipe"
        )

@router.post("/", response_model=Recipe)
async def create_recipe(
    recipe_data: RecipeCreate,
    current_user: User = Depends(verify_firebase_token)
):
    """Create a new recipe (authenticated users only)"""
    try:
        # Convert Pydantic model to dict
        recipe_dict = recipe_data.dict()
        
        # Add metadata
        recipe_dict['id'] = str(UUID())
        
        result = await supabase_service.create_recipe(recipe_dict)
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create recipe"
            )
        
        # Return the created recipe
        created_recipe_id = result.data[0]['id']
        return await get_recipe(created_recipe_id)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating recipe: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create recipe"
        )

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
