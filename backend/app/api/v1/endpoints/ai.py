from fastapi import APIRouter, HTTPException, Depends
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
from app.services.ai_service import ai_service
from app.core.security import get_current_user
from app.models.chef import Chef
import logging

logger = logging.getLogger(__name__)

router = APIRouter()

# Request models
class RecipeSuggestionRequest(BaseModel):
    ingredients: List[str]
    cuisine_preference: Optional[str] = None
    dietary_restrictions: Optional[List[str]] = None
    difficulty_level: Optional[str] = None

class IngredientSubstitutionRequest(BaseModel):
    original_ingredient: str
    recipe_context: str
    dietary_restrictions: Optional[List[str]] = None

class CookingTipsRequest(BaseModel):
    recipe_title: str
    cooking_method: str
    difficulty_level: str

class NutritionAnalysisRequest(BaseModel):
    ingredients: List[Dict[str, Any]]
    servings: int

class ImproveInstructionsRequest(BaseModel):
    current_instructions: List[str]
    recipe_title: str

# Response models
class RecipeSuggestion(BaseModel):
    title: str
    description: str
    prep_time: int
    cook_time: int
    difficulty: str
    missing_ingredients: List[str]
    key_techniques: List[str]

class IngredientSubstitution(BaseModel):
    substitute: str
    explanation: str
    ratio: str

class NutritionInfo(BaseModel):
    calories: float
    protein_g: float
    carbs_g: float
    fat_g: float
    fiber_g: float
    sugar_g: float
    sodium_mg: float
    notes: str

@router.post("/recipe-suggestions", response_model=List[RecipeSuggestion])
async def get_recipe_suggestions(
    request: RecipeSuggestionRequest,
    current_user: Chef = Depends(get_current_user)
):
    """Get AI-powered recipe suggestions based on available ingredients"""
    
    try:
        suggestions = await ai_service.generate_recipe_suggestions(
            ingredients=request.ingredients,
            cuisine_preference=request.cuisine_preference,
            dietary_restrictions=request.dietary_restrictions,
            difficulty_level=request.difficulty_level
        )
        
        return suggestions
        
    except Exception as e:
        logger.error(f"Error getting recipe suggestions: {e}")
        raise HTTPException(
            status_code=500, 
            detail="Failed to generate recipe suggestions"
        )

@router.post("/ingredient-substitutions", response_model=List[IngredientSubstitution])
async def get_ingredient_substitutions(
    request: IngredientSubstitutionRequest,
    current_user: Chef = Depends(get_current_user)
):
    """Get AI-powered ingredient substitution suggestions"""
    
    try:
        substitutions = await ai_service.suggest_ingredient_substitutions(
            original_ingredient=request.original_ingredient,
            recipe_context=request.recipe_context,
            dietary_restrictions=request.dietary_restrictions
        )
        
        return substitutions
        
    except Exception as e:
        logger.error(f"Error getting ingredient substitutions: {e}")
        raise HTTPException(
            status_code=500, 
            detail="Failed to generate ingredient substitutions"
        )

@router.post("/cooking-tips", response_model=List[str])
async def get_cooking_tips(
    request: CookingTipsRequest,
    current_user: Chef = Depends(get_current_user)
):
    """Get AI-powered cooking tips for a recipe"""
    
    try:
        tips = await ai_service.generate_cooking_tips(
            recipe_title=request.recipe_title,
            cooking_method=request.cooking_method,
            difficulty_level=request.difficulty_level
        )
        
        return tips
        
    except Exception as e:
        logger.error(f"Error getting cooking tips: {e}")
        raise HTTPException(
            status_code=500, 
            detail="Failed to generate cooking tips"
        )

@router.post("/nutrition-analysis", response_model=NutritionInfo)
async def analyze_nutrition(
    request: NutritionAnalysisRequest,
    current_user: Chef = Depends(get_current_user)
):
    """Get AI-powered nutritional analysis of a recipe"""
    
    try:
        nutrition = await ai_service.analyze_recipe_nutrition(
            ingredients=request.ingredients,
            servings=request.servings
        )
        
        return nutrition
        
    except Exception as e:
        logger.error(f"Error analyzing nutrition: {e}")
        raise HTTPException(
            status_code=500, 
            detail="Failed to analyze recipe nutrition"
        )

@router.post("/improve-instructions", response_model=List[str])
async def improve_instructions(
    request: ImproveInstructionsRequest,
    current_user: Chef = Depends(get_current_user)
):
    """Get AI-improved recipe instructions"""
    
    try:
        improved = await ai_service.improve_recipe_instructions(
            current_instructions=request.current_instructions,
            recipe_title=request.recipe_title
        )
        
        return improved
        
    except Exception as e:
        logger.error(f"Error improving instructions: {e}")
        raise HTTPException(
            status_code=500, 
            detail="Failed to improve recipe instructions"
        )

@router.get("/suggestions/quick")
async def get_quick_suggestions(
    ingredients: str,  # Comma-separated ingredients
    current_user: Chef = Depends(get_current_user)
):
    """Get quick recipe suggestions (simplified endpoint)"""
    
    try:
        ingredient_list = [ing.strip() for ing in ingredients.split(",")]
        
        suggestions = await ai_service.generate_recipe_suggestions(
            ingredients=ingredient_list,
            difficulty_level="easy"
        )
        
        # Return simplified response for quick suggestions
        return {
            "suggestions": [
                {
                    "title": s.get("title", ""),
                    "description": s.get("description", ""),
                    "time": s.get("prep_time", 0) + s.get("cook_time", 0)
                }
                for s in suggestions[:3]  # Limit to 3 quick suggestions
            ]
        }
        
    except Exception as e:
        logger.error(f"Error getting quick suggestions: {e}")
        raise HTTPException(
            status_code=500, 
            detail="Failed to generate quick suggestions"
        )
