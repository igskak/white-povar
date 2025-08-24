"""
Enhanced Pydantic models for normalized database schema

Supports multi-language content, unit standardization, and proper normalization
"""

from pydantic import BaseModel, Field, validator
from typing import List, Optional, Dict, Any, Union
from datetime import datetime
from uuid import UUID
from decimal import Decimal
import uuid


# ============================================================================
# UNITS AND MEASUREMENTS
# ============================================================================

class UnitBase(BaseModel):
    """Base unit model"""
    name_en: str = Field(..., min_length=1, max_length=50)
    name_original: Optional[str] = Field(None, max_length=50)
    original_language: Optional[str] = Field(None, max_length=5)
    abbreviation_en: str = Field(..., min_length=1, max_length=10)
    abbreviation_original: Optional[str] = Field(None, max_length=10)
    unit_type: str = Field(..., regex=r'^(mass|volume|count|length|temperature)$')
    system: str = Field(..., regex=r'^(metric|imperial|us|other)$')
    is_base_unit: bool = Field(default=False)
    is_active: bool = Field(default=True)


class Unit(UnitBase):
    """Complete unit model"""
    id: UUID = Field(default_factory=uuid.uuid4)
    base_unit_id: Optional[UUID] = None
    conversion_factor: Optional[Decimal] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    class Config:
        from_attributes = True


class UnitCreate(UnitBase):
    """Unit creation model"""
    base_unit_id: Optional[UUID] = None
    conversion_factor: Optional[Decimal] = None


# ============================================================================
# INGREDIENT CATEGORIES
# ============================================================================

class IngredientCategoryBase(BaseModel):
    """Base ingredient category model"""
    name_en: str = Field(..., min_length=1, max_length=100)
    name_original: Optional[str] = Field(None, max_length=100)
    original_language: Optional[str] = Field(None, max_length=5)
    description_en: Optional[str] = None
    icon_url: Optional[str] = None
    sort_order: int = Field(default=0)
    is_active: bool = Field(default=True)


class IngredientCategory(IngredientCategoryBase):
    """Complete ingredient category model"""
    id: UUID = Field(default_factory=uuid.uuid4)
    parent_id: Optional[UUID] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    class Config:
        from_attributes = True


class IngredientCategoryCreate(IngredientCategoryBase):
    """Ingredient category creation model"""
    parent_id: Optional[UUID] = None


# ============================================================================
# BASE INGREDIENTS
# ============================================================================

class BaseIngredientBase(BaseModel):
    """Base ingredient definition"""
    name_en: str = Field(..., min_length=1, max_length=200)
    name_original: Optional[str] = Field(None, max_length=200)
    original_language: str = Field(default="en", max_length=5)
    category_id: Optional[UUID] = None
    density_g_per_ml: Optional[Decimal] = Field(None, ge=0, le=10)
    default_unit_id: Optional[UUID] = None
    nutritional_data: Optional[Dict[str, Any]] = None
    aliases: List[str] = Field(default_factory=list)
    description_en: Optional[str] = None
    storage_tips_en: Optional[str] = None
    substitutes: List[str] = Field(default_factory=list)  # UUIDs as strings
    allergens: List[str] = Field(default_factory=list)
    is_active: bool = Field(default=True)


class BaseIngredient(BaseIngredientBase):
    """Complete base ingredient model"""
    id: UUID = Field(default_factory=uuid.uuid4)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    
    class Config:
        from_attributes = True


class BaseIngredientCreate(BaseIngredientBase):
    """Base ingredient creation model"""
    pass


# ============================================================================
# RECIPE INGREDIENTS (Junction Table)
# ============================================================================

class RecipeIngredientBase(BaseModel):
    """Recipe-ingredient relationship"""
    base_ingredient_id: UUID
    amount_canonical: Decimal = Field(..., gt=0)  # Always in metric base units
    unit_canonical_id: UUID
    amount_display: Optional[Decimal] = Field(None, gt=0)  # Original amount
    unit_display_id: Optional[UUID] = None  # Original unit
    notes: Optional[str] = None
    notes_en: Optional[str] = None
    order: int = Field(..., ge=0)
    is_optional: bool = Field(default=False)
    preparation_method: Optional[str] = None  # "chopped", "diced", etc.


class RecipeIngredient(RecipeIngredientBase):
    """Complete recipe ingredient model"""
    id: UUID = Field(default_factory=uuid.uuid4)
    recipe_id: UUID
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Related objects (populated by joins)
    base_ingredient: Optional[BaseIngredient] = None
    unit_canonical: Optional[Unit] = None
    unit_display: Optional[Unit] = None
    
    class Config:
        from_attributes = True


class RecipeIngredientCreate(RecipeIngredientBase):
    """Recipe ingredient creation model"""
    pass


# ============================================================================
# ENHANCED NUTRITION
# ============================================================================

class NutritionBase(BaseModel):
    """Enhanced nutrition information"""
    serving_size_g: Optional[Decimal] = Field(None, ge=0)
    calories_per_serving: Optional[int] = Field(None, ge=0)
    calories_per_100g: Optional[int] = Field(None, ge=0)
    protein_g: Optional[Decimal] = Field(None, ge=0)
    carbs_g: Optional[Decimal] = Field(None, ge=0)
    fat_g: Optional[Decimal] = Field(None, ge=0)
    fiber_g: Optional[Decimal] = Field(None, ge=0)
    sugar_g: Optional[Decimal] = Field(None, ge=0)
    sodium_mg: Optional[Decimal] = Field(None, ge=0)
    cholesterol_mg: Optional[Decimal] = Field(None, ge=0)
    vitamin_data: Optional[Dict[str, Any]] = None
    allergen_info: List[str] = Field(default_factory=list)
    dietary_flags: List[str] = Field(default_factory=list)  # "vegetarian", "vegan", etc.
    calculation_method: str = Field(default="estimated")  # "estimated", "calculated", "lab-tested"


class Nutrition(NutritionBase):
    """Complete nutrition model"""
    id: UUID = Field(default_factory=uuid.uuid4)
    recipe_id: UUID
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    
    class Config:
        from_attributes = True


class NutritionCreate(NutritionBase):
    """Nutrition creation model"""
    pass


# ============================================================================
# ENHANCED RECIPES
# ============================================================================

class RecipeBase(BaseModel):
    """Enhanced recipe base model with multi-language support"""
    title: str = Field(..., min_length=1, max_length=200)
    title_en: Optional[str] = Field(None, max_length=200)
    description: str = Field(..., min_length=1, max_length=1000)
    description_en: Optional[str] = None
    cuisine: str = Field(..., min_length=1, max_length=100)
    cuisine_en: Optional[str] = Field(None, max_length=100)
    category: str = Field(..., min_length=1, max_length=100)
    category_en: Optional[str] = Field(None, max_length=100)
    difficulty: int = Field(..., ge=1, le=5)
    prep_time_minutes: int = Field(..., ge=0)
    cook_time_minutes: int = Field(..., ge=0)
    servings: int = Field(..., ge=1)
    instructions: List[str] = Field(..., min_items=1)
    instructions_en: Optional[List[str]] = None
    images: List[str] = Field(default_factory=list)
    tags: List[str] = Field(default_factory=list)
    tags_en: List[str] = Field(default_factory=list)
    is_featured: bool = Field(default=False)
    original_language: str = Field(default="en", max_length=5)
    source_url: Optional[str] = None
    
    @validator('instructions')
    def validate_instructions(cls, v):
        if not v or len(v) == 0:
            raise ValueError('At least one instruction is required')
        for instruction in v:
            if not instruction.strip():
                raise ValueError('Instructions cannot be empty')
        return v
    
    @validator('tags', 'tags_en')
    def validate_tags(cls, v):
        return [tag.strip().lower() for tag in v if tag.strip()]


class RecipeCreate(RecipeBase):
    """Recipe creation model"""
    chef_id: UUID
    ingredients: List[RecipeIngredientCreate] = Field(..., min_items=1)
    nutrition: Optional[NutritionCreate] = None


class Recipe(RecipeBase):
    """Complete recipe model"""
    id: UUID = Field(default_factory=uuid.uuid4)
    chef_id: UUID
    total_time_minutes: int
    ingredients: List[RecipeIngredient] = Field(default_factory=list)
    nutrition: Optional[Nutrition] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Localization metadata (added by API layer)
    _localization: Optional[Dict[str, Any]] = None
    
    @validator('total_time_minutes', always=True)
    def calculate_total_time(cls, v, values):
        prep_time = values.get('prep_time_minutes', 0)
        cook_time = values.get('cook_time_minutes', 0)
        return prep_time + cook_time
    
    class Config:
        from_attributes = True


class RecipeList(BaseModel):
    """Recipe list response"""
    recipes: List[Recipe]
    total_count: int
    has_more: bool
    _meta: Optional[Dict[str, Any]] = None  # Localization metadata


# ============================================================================
# LEGACY COMPATIBILITY MODELS
# ============================================================================

class LegacyIngredient(BaseModel):
    """Legacy ingredient model for backward compatibility"""
    id: UUID = Field(default_factory=uuid.uuid4)
    recipe_id: UUID
    name: str = Field(..., min_length=1, max_length=200)
    amount: float = Field(..., gt=0)
    unit: str = Field(..., min_length=1, max_length=50)
    notes: Optional[str] = Field(None, max_length=500)
    order: int = Field(..., ge=0)
    
    class Config:
        from_attributes = True


# ============================================================================
# CONVERSION UTILITIES
# ============================================================================

def convert_legacy_ingredient_to_normalized(legacy: LegacyIngredient) -> RecipeIngredientCreate:
    """Convert legacy ingredient to normalized format"""
    from app.services.normalization import data_normalizer
    
    # Normalize the ingredient data
    normalized_data = data_normalizer._normalize_ingredient_data({
        'name': legacy.name,
        'amount': legacy.amount,
        'unit': legacy.unit,
        'notes': legacy.notes,
        'order': legacy.order
    })
    
    # This would need to look up or create base_ingredient_id and unit IDs
    # For now, return a placeholder structure
    return RecipeIngredientCreate(
        base_ingredient_id=uuid.uuid4(),  # Would be looked up/created
        amount_canonical=Decimal(str(normalized_data['amount_canonical'])),
        unit_canonical_id=uuid.uuid4(),  # Would be looked up
        amount_display=Decimal(str(legacy.amount)),
        unit_display_id=uuid.uuid4(),  # Would be looked up
        notes=legacy.notes,
        order=legacy.order
    )
