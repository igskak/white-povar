from fastapi import APIRouter, HTTPException, status, Depends, Query
from typing import List, Optional, Dict, Any
import logging
import base64
import io
from PIL import Image, ImageFile
from pydantic import BaseModel

from app.schemas.search import PhotoSearchRequest, PhotoSearchResponse, TextSearchRequest, TextSearchResponse
from app.schemas.recipe import Recipe
from app.services.database import supabase_service
from app.services.openai_service import openai_service
from app.core.security import get_current_user
from app.schemas.chef import Chef

router = APIRouter()
logger = logging.getLogger(__name__)

# Helper functions for data mapping
async def _get_category_name_from_id(category_id: str) -> str:
    """Get category name from category_id"""
    if not category_id:
        return "Main Course"

    try:
        result = await supabase_service.execute_query(
            'recipe_categories', 'select', filters={'id': category_id}
        )
        if result.data and len(result.data) > 0:
            return result.data[0].get('name_en', 'Main Course')
        return "Main Course"
    except Exception as e:
        logger.error(f"Error getting category name for {category_id}: {str(e)}")
        return "Main Course"

async def _get_unit_name_from_id(unit_id: str) -> str:
    """Get unit name from unit_id"""
    if not unit_id:
        return "unit"

    try:
        result = await supabase_service.execute_query(
            'units', 'select', filters={'id': unit_id}
        )
        if result.data and len(result.data) > 0:
            return result.data[0].get('name_en', 'unit')
        return "unit"
    except Exception as e:
        logger.error(f"Error getting unit name for {unit_id}: {str(e)}")
        return "unit"

# Advanced Search Models
class AdvancedSearchFilters(BaseModel):
    query: Optional[str] = None
    cuisine: Optional[str] = None
    category: Optional[str] = None
    difficulty: Optional[int] = None
    max_prep_time: Optional[int] = None
    max_cook_time: Optional[int] = None
    max_total_time: Optional[int] = None
    dietary_restrictions: Optional[List[str]] = None
    ingredients: Optional[List[str]] = None
    chef_id: Optional[str] = None
    is_featured: Optional[bool] = None
    tags: Optional[List[str]] = None
    min_servings: Optional[int] = None
    max_servings: Optional[int] = None
    sort_by: str = "created_at"
    sort_order: str = "desc"

class AdvancedSearchResponse(BaseModel):
    recipes: List[Recipe]
    total_count: int
    page: int
    page_size: int
    total_pages: int
    has_next: bool
    has_prev: bool
    filters_applied: Dict[str, Any]

class SearchSuggestions(BaseModel):
    recipes: List[str]
    cuisines: List[str]
    ingredients: List[str]
    tags: List[str]

class FilterOptions(BaseModel):
    cuisines: List[str]
    categories: List[str]
    difficulty_range: Dict[str, int]
    time_ranges: Dict[str, Dict[str, int]]
    servings_range: Dict[str, int]
    popular_tags: List[str]
    dietary_restrictions: List[str]

@router.post("/photo", response_model=PhotoSearchResponse)
async def search_by_photo(request: PhotoSearchRequest):
    """Search recipes by analyzing ingredients in a photo using OpenAI Vision"""
    try:
        # Validate and process the image
        try:
            # Decode base64 image
            try:
                image_data = base64.b64decode(request.image)
                logger.info(f"Decoded image data size: {len(image_data)} bytes")
            except Exception as e:
                logger.error(f"Base64 decode error: {str(e)}")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Invalid base64 image data"
                )

            # Check minimum image size
            if len(image_data) < 100:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Image data too small"
                )

            # Open image with PIL
            try:
                image = Image.open(io.BytesIO(image_data))
                # Ensure image is loaded and format is detected
                image.load()
            except Exception as e:
                logger.error(f"PIL image open error: {str(e)}")
                # Try to handle truncated images
                try:
                    from PIL import ImageFile
                    ImageFile.LOAD_TRUNCATED_IMAGES = True
                    image = Image.open(io.BytesIO(image_data))
                    image.load()
                except Exception as e2:
                    logger.error(f"Failed to load truncated image: {str(e2)}")
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Cannot process image file"
                    )

            # If format is None, try to detect from image data
            if image.format is None:
                # Try to detect format from the first few bytes
                if image_data.startswith(b'\xff\xd8\xff'):
                    image.format = 'JPEG'
                elif image_data.startswith(b'\x89PNG'):
                    image.format = 'PNG'
                elif image_data.startswith(b'RIFF') and b'WEBP' in image_data[:12]:
                    image.format = 'WEBP'
                else:
                    # Default to JPEG for unknown formats
                    image.format = 'JPEG'

            # Validate image format (more lenient)
            supported_formats = ['JPEG', 'PNG', 'WEBP', 'JPG']
            if image.format not in supported_formats:
                logger.warning(f"Unsupported format {image.format}, converting to JPEG")
                # Convert to RGB if necessary and set format to JPEG
                if image.mode in ('RGBA', 'LA', 'P'):
                    image = image.convert('RGB')
                image.format = 'JPEG'

            # Resize image if too large (OpenAI has size limits)
            max_size = (1024, 1024)
            if image.size[0] > max_size[0] or image.size[1] > max_size[1]:
                image.thumbnail(max_size, Image.Resampling.LANCZOS)

                # Convert back to base64
                buffer = io.BytesIO()
                save_format = 'JPEG' if image.format == 'JPG' else image.format
                image.save(buffer, format=save_format)
                request.image = base64.b64encode(buffer.getvalue()).decode()
                
        except Exception as e:
            logger.error(f"Image processing error: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid image data"
            )
        
        # Analyze image with OpenAI Vision
        try:
            vision_result = await openai_service.analyze_ingredients(request.image)
            detected_ingredients = vision_result.get('ingredients', [])
            confidence_score = vision_result.get('confidence', 0.0)
            
            if not detected_ingredients:
                return PhotoSearchResponse(
                    ingredients=[],
                    suggested_recipes=[],
                    confidence_score=0.0
                )
                
        except Exception as e:
            logger.error(f"OpenAI Vision API error: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to analyze image"
            )
        
        # Search for recipes that contain the detected ingredients
        try:
            suggested_recipes = await _find_recipes_by_ingredients(
                detected_ingredients, 
                request.chef_id,
                request.max_results
            )
            
            return PhotoSearchResponse(
                ingredients=detected_ingredients,
                suggested_recipes=suggested_recipes,
                confidence_score=confidence_score
            )
            
        except Exception as e:
            logger.error(f"Recipe search error: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to find matching recipes"
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Photo search error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Photo search failed"
        )

@router.get("/text", response_model=TextSearchResponse)
async def search_by_text(
    q: str,
    chef_id: Optional[str] = None,
    limit: int = 20,
    offset: int = 0
):
    """Search recipes by text query"""
    try:
        if not q or len(q.strip()) < 2:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Search query must be at least 2 characters long"
            )
        
        # Search recipes using database service
        result = await supabase_service.search_recipes_by_text(
            q.strip(), chef_id, limit, offset
        )
        
        if not result.data:
            return TextSearchResponse(
                recipes=[],
                total_count=0,
                query=q
            )
        
        recipes = []
        for recipe_data in result.data:
            try:
                # Ingredients are now included via JOIN, no need for separate query
                # Extract ingredients from the nested structure
                ingredients = recipe_data.pop('recipe_ingredients', [])

                # Map database fields to Recipe model fields
                # Handle difficulty_level -> difficulty
                if 'difficulty_level' in recipe_data:
                    recipe_data['difficulty'] = recipe_data.pop('difficulty_level', 1)

                # Handle category_id -> category (get category name)
                if 'category_id' in recipe_data:
                    category_id = recipe_data.pop('category_id', None)
                    recipe_data['category'] = await _get_category_name_from_id(category_id) if category_id else "Main Course"

                # Add missing required fields with defaults
                if 'cuisine' not in recipe_data or not recipe_data['cuisine']:
                    recipe_data['cuisine'] = "International"

                # Handle instructions - convert TEXT to List[str]
                if 'instructions' in recipe_data and isinstance(recipe_data['instructions'], str):
                    # Split by newlines and filter out empty lines
                    instructions_list = [line.strip() for line in recipe_data['instructions'].split('\n') if line.strip()]
                    recipe_data['instructions'] = instructions_list if instructions_list else ["No instructions provided"]
                elif 'instructions' not in recipe_data:
                    recipe_data['instructions'] = ["No instructions provided"]

                # Process ingredients to match expected format
                processed_ingredients = []
                for i, ingredient in enumerate(ingredients):
                    processed_ingredient = {
                        'id': ingredient.get('id'),
                        'recipe_id': recipe_data['id'],
                        'name': ingredient.get('display_name', 'Unknown ingredient'),
                        'amount': float(ingredient.get('amount', 0)),
                        'unit': await _get_unit_name_from_id(ingredient.get('unit_id')) if ingredient.get('unit_id') else 'unit',
                        'notes': ingredient.get('preparation_notes', ''),
                        'order': ingredient.get('sort_order', i)
                    }
                    processed_ingredients.append(processed_ingredient)

                recipe_data['ingredients'] = processed_ingredients

                # Ensure other required fields have defaults
                recipe_data.setdefault('images', [])
                recipe_data.setdefault('tags', [])
                recipe_data.setdefault('is_featured', False)
                recipe_data.setdefault('video_url', None)
                recipe_data.setdefault('video_file_path', None)

                recipe = Recipe(**recipe_data)
                recipes.append(recipe)

            except Exception as e:
                logger.error(f"Error processing recipe {recipe_data.get('id', 'unknown')}: {str(e)}")
                continue
        
        return TextSearchResponse(
            recipes=recipes,
            total_count=len(recipes),
            query=q
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Text search error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Text search failed"
        )

async def _find_recipes_by_ingredients(
    ingredients: List[str],
    chef_id: Optional[str] = None,
    max_results: int = 10
) -> List[Recipe]:
    """Find recipes that contain the detected ingredients"""
    try:
        # Get all recipes (filtered by chef if specified)
        filters = {}
        if chef_id:
            filters['chef_id'] = chef_id

        # Use JOINed query to include recipe_ingredients to avoid N+1
        result = await supabase_service.get_recipes(filters, limit=100, offset=0)

        if not result.data:
            return []

        # Score recipes based on ingredient matches
        scored_recipes = []

        for recipe_data in result.data:
            try:
                # Ingredients are included via JOIN
                join_ingredients = recipe_data.pop('recipe_ingredients', []) or []

                recipe_ingredient_names = [
                    (ing.get('display_name') or '').lower()
                    for ing in join_ingredients if ing.get('display_name')
                ]
                detected_lower = [ing.lower() for ing in ingredients]

                matches = 0
                for detected_ing in detected_lower:
                    for recipe_ing in recipe_ingredient_names:
                        if detected_ing in recipe_ing or recipe_ing in detected_ing:
                            matches += 1
                            break

                # Map DB fields to Recipe schema (align with advanced_search path)
                if 'difficulty_level' in recipe_data:
                    recipe_data['difficulty'] = recipe_data.pop('difficulty_level', 1)

                if 'category_id' in recipe_data:
                    category_id = recipe_data.pop('category_id', None)
                    recipe_data['category'] = await _get_category_name_from_id(category_id) if category_id else "Main Course"

                if 'cuisine' not in recipe_data or not recipe_data['cuisine']:
                    recipe_data['cuisine'] = "International"

                # Instructions - convert TEXT to List[str]
                if 'instructions' in recipe_data and isinstance(recipe_data['instructions'], str):
                    instructions_list = [line.strip() for line in recipe_data['instructions'].split('\n') if line.strip()]
                    recipe_data['instructions'] = instructions_list if instructions_list else ["No instructions provided"]
                elif 'instructions' not in recipe_data:
                    recipe_data['instructions'] = ["No instructions provided"]

                # Process ingredients to match expected format
                processed_ingredients = []
                for i, ing in enumerate(join_ingredients):
                    processed_ingredients.append({
                        'id': ing.get('id'),
                        'recipe_id': recipe_data['id'],
                        'name': ing.get('display_name', 'Unknown ingredient'),
                        'amount': float(ing.get('amount', 0) or 0),
                        'unit': await _get_unit_name_from_id(ing.get('unit_id')) if ing.get('unit_id') else 'unit',
                        'notes': ing.get('preparation_notes', '') or '',
                        'order': ing.get('sort_order', i) if ing.get('sort_order') is not None else i,
                    })
                recipe_data['ingredients'] = processed_ingredients

                # Ensure other required fields have defaults
                recipe_data.setdefault('images', [])
                recipe_data.setdefault('tags', [])
                recipe_data.setdefault('is_featured', False)
                recipe_data.setdefault('video_url', None)
                recipe_data.setdefault('video_file_path', None)

                if matches > 0:
                    score = matches / (len(recipe_ingredient_names) or 1)
                    scored_recipes.append((score, Recipe(**recipe_data)))
            except Exception as inner_e:
                logger.error(f"Error processing recipe {recipe_data.get('id', 'unknown')} in photo search: {str(inner_e)}")
                continue

        # Sort by score (highest first) and return top results
        scored_recipes.sort(key=lambda x: x[0], reverse=True)
        return [recipe for _, recipe in scored_recipes[:max_results]]

    except Exception as e:
        logger.error(f"Error finding recipes by ingredients: {str(e)}")
        return []

@router.get("/suggestions")
async def get_search_suggestions(
    q: str,
    chef_id: Optional[str] = None,
    limit: int = 5
):
    """Get search suggestions based on partial query"""
    try:
        if len(q.strip()) < 2:
            return {"suggestions": []}
        
        # Simple implementation - search recipe titles and return unique suggestions
        result = await supabase_service.search_recipes_by_text(q, chef_id, limit * 2, 0)
        
        suggestions = []
        seen = set()
        
        for recipe_data in result.data:
            title = recipe_data['title']
            if title not in seen:
                suggestions.append(title)
                seen.add(title)
                
            if len(suggestions) >= limit:
                break
        
        return {"suggestions": suggestions}

    except Exception as e:
        logger.error(f"Error getting search suggestions: {str(e)}")
        return {"suggestions": []}

@router.post("/advanced", response_model=AdvancedSearchResponse)
async def advanced_search(
    filters: AdvancedSearchFilters,
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page"),
    current_user: Chef = Depends(get_current_user)
):
    """
    Advanced recipe search with comprehensive filtering
    """
    try:
        # Build search query for Supabase
        query_filters = {}

        # Apply filters
        if filters.chef_id:
            query_filters['chef_id'] = filters.chef_id

        if filters.cuisine:
            query_filters['cuisine'] = f"ilike.%{filters.cuisine}%"

        if filters.category:
            query_filters['category'] = f"ilike.%{filters.category}%"

        if filters.difficulty:
            query_filters['difficulty'] = f"eq.{filters.difficulty}"

        if filters.max_prep_time:
            query_filters['prep_time_minutes'] = f"lte.{filters.max_prep_time}"

        if filters.max_cook_time:
            query_filters['cook_time_minutes'] = f"lte.{filters.max_cook_time}"

        if filters.max_total_time:
            query_filters['total_time_minutes'] = f"lte.{filters.max_total_time}"

        if filters.min_servings:
            query_filters['servings'] = f"gte.{filters.min_servings}"

        if filters.max_servings:
            query_filters['servings'] = f"lte.{filters.max_servings}"

        if filters.is_featured is not None:
            query_filters['is_featured'] = f"eq.{filters.is_featured}"

        # Calculate offset for pagination
        offset = (page - 1) * page_size

        # Execute search with JOIN to include ingredients
        result = await supabase_service.get_recipes(
            filters=query_filters,
            limit=page_size,
            offset=offset
        )

        recipes = []
        if result.data:
            for recipe_data in result.data:
                try:
                    # Ingredients are now included via JOIN, no need for separate query
                    ingredients = recipe_data.pop('recipe_ingredients', [])

                    # Map database fields to Recipe model fields (same as text search)
                    # Handle difficulty_level -> difficulty
                    if 'difficulty_level' in recipe_data:
                        recipe_data['difficulty'] = recipe_data.pop('difficulty_level', 1)

                    # Handle category_id -> category (get category name)
                    if 'category_id' in recipe_data:
                        category_id = recipe_data.pop('category_id', None)
                        recipe_data['category'] = await _get_category_name_from_id(category_id) if category_id else "Main Course"

                    # Add missing required fields with defaults
                    if 'cuisine' not in recipe_data or not recipe_data['cuisine']:
                        recipe_data['cuisine'] = "International"

                    # Handle instructions - convert TEXT to List[str]
                    if 'instructions' in recipe_data and isinstance(recipe_data['instructions'], str):
                        # Split by newlines and filter out empty lines
                        instructions_list = [line.strip() for line in recipe_data['instructions'].split('\n') if line.strip()]
                        recipe_data['instructions'] = instructions_list if instructions_list else ["No instructions provided"]
                    elif 'instructions' not in recipe_data:
                        recipe_data['instructions'] = ["No instructions provided"]

                    # Process ingredients to match expected format
                    processed_ingredients = []
                    for i, ingredient in enumerate(ingredients):
                        processed_ingredient = {
                            'id': ingredient.get('id'),
                            'recipe_id': recipe_data['id'],
                            'name': ingredient.get('display_name', 'Unknown ingredient'),
                            'amount': float(ingredient.get('amount', 0)),
                            'unit': await _get_unit_name_from_id(ingredient.get('unit_id')) if ingredient.get('unit_id') else 'unit',
                            'notes': ingredient.get('preparation_notes', ''),
                            'order': ingredient.get('sort_order', i)
                        }
                        processed_ingredients.append(processed_ingredient)

                    recipe_data['ingredients'] = processed_ingredients

                    # Ensure other required fields have defaults
                    recipe_data.setdefault('images', [])
                    recipe_data.setdefault('tags', [])
                    recipe_data.setdefault('is_featured', False)
                    recipe_data.setdefault('video_url', None)
                    recipe_data.setdefault('video_file_path', None)

                    # Apply text search filter if provided
                    if filters.query:
                        query_lower = filters.query.lower()
                        title_match = query_lower in recipe_data.get('title', '').lower()
                        desc_match = query_lower in recipe_data.get('description', '').lower()
                        ingredient_match = any(
                            query_lower in ing.get('name', '').lower()
                            for ing in recipe_data['ingredients']
                        )

                        if not (title_match or desc_match or ingredient_match):
                            continue

                    # Apply dietary restrictions filter
                    if filters.dietary_restrictions:
                        recipe_tags = recipe_data.get('tags', []) or []
                        if not any(restriction in recipe_tags for restriction in filters.dietary_restrictions):
                            continue

                    # Apply tags filter
                    if filters.tags:
                        recipe_tags = recipe_data.get('tags', []) or []
                        if not any(tag in recipe_tags for tag in filters.tags):
                            continue

                    # Apply ingredients filter
                    if filters.ingredients:
                        recipe_ingredients = [ing.get('name', '').lower() for ing in recipe_data['ingredients']]
                        if not any(
                            any(filter_ing.lower() in recipe_ing for recipe_ing in recipe_ingredients)
                            for filter_ing in filters.ingredients
                        ):
                            continue

                    recipe = Recipe(**recipe_data)
                    recipes.append(recipe)

                except Exception as e:
                    logger.error(f"Error processing recipe {recipe_data.get('id', 'unknown')} in advanced search: {str(e)}")
                    continue

        # Get total count (simplified - in production you'd do a separate count query)
        total_count = len(recipes)
        total_pages = (total_count + page_size - 1) // page_size

        return AdvancedSearchResponse(
            recipes=recipes,
            total_count=total_count,
            page=page,
            page_size=page_size,
            total_pages=total_pages,
            has_next=page < total_pages,
            has_prev=page > 1,
            filters_applied=filters.model_dump(exclude_none=True)
        )

    except Exception as e:
        logger.error(f"Advanced search error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Advanced search failed"
        )

@router.get("/filters", response_model=FilterOptions)
async def get_filter_options():
    """
    Get available filter options for the search interface
    """
    try:
        # Get all recipes to analyze available options
        result = await supabase_service.get_recipes(filters={}, limit=1000, offset=0)

        cuisines = set()
        categories = set()
        difficulties = []
        prep_times = []
        cook_times = []
        total_times = []
        servings = []
        all_tags = set()

        if result.data:
            for recipe_data in result.data:
                if recipe_data.get('cuisine'):
                    cuisines.add(recipe_data['cuisine'])

                if recipe_data.get('category'):
                    categories.add(recipe_data['category'])

                if recipe_data.get('difficulty'):
                    difficulties.append(recipe_data['difficulty'])

                if recipe_data.get('prep_time_minutes'):
                    prep_times.append(recipe_data['prep_time_minutes'])

                if recipe_data.get('cook_time_minutes'):
                    cook_times.append(recipe_data['cook_time_minutes'])

                if recipe_data.get('total_time_minutes'):
                    total_times.append(recipe_data['total_time_minutes'])

                if recipe_data.get('servings'):
                    servings.append(recipe_data['servings'])

                if recipe_data.get('tags'):
                    all_tags.update(recipe_data['tags'])

        return FilterOptions(
            cuisines=sorted(list(cuisines)),
            categories=sorted(list(categories)),
            difficulty_range={
                "min": min(difficulties) if difficulties else 1,
                "max": max(difficulties) if difficulties else 5
            },
            time_ranges={
                "prep_time": {
                    "min": min(prep_times) if prep_times else 0,
                    "max": max(prep_times) if prep_times else 180
                },
                "cook_time": {
                    "min": min(cook_times) if cook_times else 0,
                    "max": max(cook_times) if cook_times else 300
                },
                "total_time": {
                    "min": min(total_times) if total_times else 0,
                    "max": max(total_times) if total_times else 480
                }
            },
            servings_range={
                "min": min(servings) if servings else 1,
                "max": max(servings) if servings else 12
            },
            popular_tags=sorted(list(all_tags))[:20],  # Top 20 tags
            dietary_restrictions=[
                "vegetarian", "vegan", "gluten-free", "dairy-free",
                "nut-free", "low-carb", "keto", "paleo", "low-sodium"
            ]
        )

    except Exception as e:
        logger.error(f"Error getting filter options: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get filter options"
        )
