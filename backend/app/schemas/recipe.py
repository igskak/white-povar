from pydantic import BaseModel, Field, validator
from typing import List, Optional, Dict, Any
from datetime import datetime
from uuid import UUID
import uuid
import re

class IngredientBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    amount: float = Field(..., ge=0)  # Allow 0 for "to taste" ingredients
    unit: str = Field(..., min_length=1, max_length=50)
    notes: Optional[str] = Field(None, max_length=500)
    order: int = Field(..., ge=0)

class IngredientCreate(IngredientBase):
    pass

class Ingredient(IngredientBase):
    id: UUID = Field(default_factory=uuid.uuid4)
    recipe_id: UUID
    
    class Config:
        from_attributes = True

class NutritionBase(BaseModel):
    calories: Optional[int] = Field(None, ge=0)
    protein_g: Optional[float] = Field(None, ge=0)
    carbs_g: Optional[float] = Field(None, ge=0)
    fat_g: Optional[float] = Field(None, ge=0)
    fiber_g: Optional[float] = Field(None, ge=0)
    sugar_g: Optional[float] = Field(None, ge=0)
    sodium_mg: Optional[float] = Field(None, ge=0)

class Nutrition(NutritionBase):
    id: UUID = Field(default_factory=uuid.uuid4)
    recipe_id: UUID
    
    class Config:
        from_attributes = True

class RecipeBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: str = Field(..., min_length=1, max_length=1000)
    cuisine: str = Field(..., min_length=1, max_length=100)
    category: str = Field(..., min_length=1, max_length=100)
    difficulty: int = Field(..., ge=1, le=5)
    prep_time_minutes: int = Field(..., ge=0)
    cook_time_minutes: int = Field(..., ge=0)
    servings: int = Field(..., ge=1)
    instructions: List[str] = Field(..., min_items=1)
    images: List[str] = Field(default_factory=list)
    video_url: Optional[str] = Field(None, description="External video URL (YouTube, TikTok, etc.)")
    video_file_path: Optional[str] = Field(None, description="Path to uploaded video file in storage")
    tags: List[str] = Field(default_factory=list)
    is_featured: bool = Field(default=False)
    
    @validator('instructions')
    def validate_instructions(cls, v):
        if not v or len(v) == 0:
            raise ValueError('At least one instruction is required')
        for instruction in v:
            if not instruction.strip():
                raise ValueError('Instructions cannot be empty')
        return v
    
    @validator('tags')
    def validate_tags(cls, v):
        return [tag.strip().lower() for tag in v if tag.strip()]

    @validator('video_url')
    def validate_video_url(cls, v):
        if v is None:
            return v

        # Supported video platforms
        supported_patterns = [
            r'https?://(www\.)?(youtube\.com/watch\?v=|youtu\.be/)',  # YouTube
            r'https?://(www\.)?tiktok\.com/',  # TikTok
            r'https?://(www\.)?instagram\.com/(p|reel)/',  # Instagram
            r'https?://(www\.)?vimeo\.com/',  # Vimeo
            r'https?://(www\.)?facebook\.com/.*/videos/',  # Facebook
            r'https?://(www\.)?dailymotion\.com/video/',  # Dailymotion
        ]

        if not any(re.match(pattern, v) for pattern in supported_patterns):
            raise ValueError('Video URL must be from a supported platform (YouTube, TikTok, Instagram, Vimeo, Facebook, Dailymotion)')

        return v

class RecipeCreate(RecipeBase):
    chef_id: UUID
    ingredients: List[IngredientCreate] = Field(..., min_items=1)
    nutrition: Optional[NutritionBase] = None

class RecipeUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = Field(None, min_length=1, max_length=1000)
    cuisine: Optional[str] = Field(None, min_length=1, max_length=100)
    category: Optional[str] = Field(None, min_length=1, max_length=100)
    difficulty: Optional[int] = Field(None, ge=1, le=5)
    prep_time_minutes: Optional[int] = Field(None, ge=0)
    cook_time_minutes: Optional[int] = Field(None, ge=0)
    servings: Optional[int] = Field(None, ge=1)
    instructions: Optional[List[str]] = None
    images: Optional[List[str]] = None
    video_url: Optional[str] = None
    video_file_path: Optional[str] = None
    tags: Optional[List[str]] = None
    is_featured: Optional[bool] = None

class Recipe(RecipeBase):
    id: UUID = Field(default_factory=uuid.uuid4)
    chef_id: UUID
    total_time_minutes: int
    ingredients: List[Ingredient] = Field(default_factory=list)
    nutrition: Optional[Nutrition] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    
    @validator('total_time_minutes', always=True)
    def calculate_total_time(cls, v, values):
        prep_time = values.get('prep_time_minutes', 0)
        cook_time = values.get('cook_time_minutes', 0)
        return prep_time + cook_time
    
    class Config:
        from_attributes = True

class RecipeList(BaseModel):
    recipes: List[Recipe]
    total_count: int
    has_more: bool

class RecipeVideoBase(BaseModel):
    filename: str = Field(..., min_length=1, max_length=255)
    file_path: str = Field(..., min_length=1)
    file_size: int = Field(..., gt=0)
    mime_type: str = Field(..., min_length=1, max_length=100)
    duration_seconds: Optional[int] = Field(None, gt=0)
    width: Optional[int] = Field(None, gt=0)
    height: Optional[int] = Field(None, gt=0)

    @validator('mime_type')
    def validate_mime_type(cls, v):
        allowed_types = [
            'video/mp4', 'video/mpeg', 'video/quicktime', 'video/x-msvideo',
            'video/webm', 'video/ogg', 'video/3gpp', 'video/x-flv'
        ]
        if v not in allowed_types:
            raise ValueError(f'Unsupported video format. Allowed: {", ".join(allowed_types)}')
        return v

class RecipeVideoCreate(RecipeVideoBase):
    recipe_id: UUID
    uploaded_by: Optional[UUID] = None

class RecipeVideo(RecipeVideoBase):
    id: UUID = Field(default_factory=uuid.uuid4)
    recipe_id: UUID
    uploaded_by: Optional[UUID] = None
    uploaded_at: datetime = Field(default_factory=datetime.utcnow)
    is_active: bool = Field(default=True)

    class Config:
        from_attributes = True
    
class RecipeFilters(BaseModel):
    cuisine: Optional[str] = None
    difficulty: Optional[int] = Field(None, ge=1, le=5)
    max_time: Optional[int] = Field(None, ge=0)
    category: Optional[str] = None
    chef_id: Optional[UUID] = None
    tags: Optional[List[str]] = None
    is_featured: Optional[bool] = None
    limit: int = Field(default=20, ge=1, le=100)
    offset: int = Field(default=0, ge=0)
