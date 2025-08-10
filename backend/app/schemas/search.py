from pydantic import BaseModel, Field, validator
from typing import List, Optional
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

class IngredientMatch(BaseModel):
    ingredient: str
    confidence: float = Field(..., ge=0, le=1)
    detected_in_image: bool
