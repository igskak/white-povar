from fastapi import APIRouter, HTTPException, status, Depends
from typing import List, Optional
import logging
import base64
import io
from PIL import Image

from app.schemas.search import PhotoSearchRequest, PhotoSearchResponse, TextSearchRequest, TextSearchResponse
from app.schemas.recipe import Recipe
from app.services.database import supabase_service
from app.services.openai_service import openai_service

router = APIRouter()
logger = logging.getLogger(__name__)

@router.post("/photo", response_model=PhotoSearchResponse)
async def search_by_photo(request: PhotoSearchRequest):
    """Search recipes by analyzing ingredients in a photo using OpenAI Vision"""
    try:
        # Validate and process the image
        try:
            image_data = base64.b64decode(request.image)
            image = Image.open(io.BytesIO(image_data))
            
            # Validate image format and size
            if image.format not in ['JPEG', 'PNG', 'WEBP']:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Image must be in JPEG, PNG, or WEBP format"
                )
            
            # Resize image if too large (OpenAI has size limits)
            max_size = (1024, 1024)
            if image.size[0] > max_size[0] or image.size[1] > max_size[1]:
                image.thumbnail(max_size, Image.Resampling.LANCZOS)
                
                # Convert back to base64
                buffer = io.BytesIO()
                image.save(buffer, format=image.format)
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
            # Get ingredients for each recipe
            ingredients_result = await supabase_service.execute_query(
                'ingredients', 'select',
                filters={'recipe_id': recipe_data['id']}
            )
            recipe_data['ingredients'] = ingredients_result.data or []
            
            recipe = Recipe(**recipe_data)
            recipes.append(recipe)
        
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
            
        result = await supabase_service.get_recipes(filters, limit=100, offset=0)
        
        if not result.data:
            return []
        
        # Score recipes based on ingredient matches
        scored_recipes = []
        
        for recipe_data in result.data:
            # Get ingredients for this recipe
            ingredients_result = await supabase_service.execute_query(
                'ingredients', 'select',
                filters={'recipe_id': recipe_data['id']}
            )
            recipe_data['ingredients'] = ingredients_result.data or []
            
            # Calculate match score
            recipe_ingredients = [ing['name'].lower() for ing in recipe_data['ingredients']]
            detected_lower = [ing.lower() for ing in ingredients]
            
            matches = 0
            for detected_ing in detected_lower:
                for recipe_ing in recipe_ingredients:
                    if detected_ing in recipe_ing or recipe_ing in detected_ing:
                        matches += 1
                        break
            
            if matches > 0:
                score = matches / len(recipe_ingredients) if recipe_ingredients else 0
                scored_recipes.append((score, Recipe(**recipe_data)))
        
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
