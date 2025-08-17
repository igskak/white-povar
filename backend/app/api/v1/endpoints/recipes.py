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
            # For now, skip ingredients to avoid the error
            # TODO: Fix ingredients query once we understand the schema
            recipe_data['ingredients'] = []

            # Convert to Recipe model
            recipe = Recipe(**recipe_data)
            recipes.append(recipe)
        
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
            # For now, skip ingredients to avoid the error
            # TODO: Fix ingredients query once we understand the schema
            recipe_data['ingredients'] = []

            recipe = Recipe(**recipe_data)
            recipes.append(recipe)
        
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
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Recipe not found"
            )
        
        recipe_data = result.data[0]
        
        # Get nutrition data if available
        nutrition_result = await supabase_service.execute_query(
            'nutrition', 'select',
            filters={'recipe_id': recipe_id}
        )
        if nutrition_result.data:
            recipe_data['nutrition'] = nutrition_result.data[0]
        
        recipe = Recipe(**recipe_data)
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
