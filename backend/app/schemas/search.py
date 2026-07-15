from pydantic import BaseModel, Field, validator
from typing import Dict, List, Optional
from uuid import UUID
import base64

from app.schemas.recipe import Recipe

class PhotoSearchRequest(BaseModel):
    image: str = Field(..., description="Base64 encoded image")
    chef_id: Optional[UUID] = None
    max_results: int = Field(default=10, ge=1, le=50)
    
    @validator('image')
    def validate_base64_image(cls, v):
        try:
            # Check if it's valid base64
            base64.b64decode(v)
            return v
        except Exception:
            raise ValueError('Image must be valid base64 encoded string')

class PhotoSearchResponse(BaseModel):
    ingredients: List[str] = Field(description="Detected ingredients from the image")
    suggested_recipes: List[Recipe] = Field(description="Recipes that can be made with detected ingredients")
    confidence_score: float = Field(description="Confidence score of ingredient detection (0-1)")

class TextSearchRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=200)
    chef_id: Optional[UUID] = None
    limit: int = Field(default=20, ge=1, le=100)
    offset: int = Field(default=0, ge=0)

class TextSearchResponse(BaseModel):
    recipes: List[Recipe]
    total_count: int
    query: str
    limit: int = 20
    offset: int = 0
    next_offset: Optional[int] = None
    has_more: bool = False


class CatalogSearchResponse(TextSearchResponse):
    """Tenant-scoped discovery response with stable offset pagination."""

    facets: Dict[str, List[str]] = Field(default_factory=dict)


class VoiceIntent(BaseModel):
    """A deliberately small, validated representation of a cooking request."""

    occasion: Optional[str] = Field(None, max_length=40)
    available_ingredients: List[str] = Field(default_factory=list, max_items=12)
    excluded_ingredients: List[str] = Field(default_factory=list, max_items=12)
    dish_type: Optional[str] = Field(None, max_length=40)
    protein: Optional[str] = Field(None, max_length=40)
    lightness: Optional[str] = Field(None, pattern='^(light|hearty)$')
    max_total_time: Optional[int] = Field(None, ge=1, le=1440)
    diets: List[str] = Field(default_factory=list, max_items=12)
    allergens: List[str] = Field(default_factory=list, max_items=24)
    servings: Optional[int] = Field(None, ge=1, le=30)
    search_terms: List[str] = Field(default_factory=list, max_items=12)


class VoiceIntentRequest(BaseModel):
    transcript: str = Field(..., min_length=2, max_length=500)
    confirmed_servings: Optional[int] = Field(None, ge=1, le=30)


class VoiceIntentRetrievalResponse(BaseModel):
    intent: VoiceIntent
    confirmation_required: List[str] = Field(default_factory=list)
    recipes: List[Recipe]
    total_count: int
    recommendations: List['VoiceRecommendation'] = Field(default_factory=list)


class VoiceRecommendation(BaseModel):
    """A safe, presentation-ready explanation of a catalog recommendation."""

    recipe: Recipe
    match_type: str = Field(..., pattern='^(exact|partial)$')
    why_it_fits: List[str] = Field(default_factory=list, max_items=4)
    missing_ingredients: List[str] = Field(default_factory=list, max_items=3)

class IngredientMatch(BaseModel):
    ingredient: str
    confidence: float = Field(..., ge=0, le=1)
    detected_in_image: bool
