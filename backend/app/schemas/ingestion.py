from pydantic import BaseModel, Field, validator
from typing import List, Optional, Dict, Any
from uuid import UUID
from datetime import datetime
from enum import Enum


class IngestionStatus(str, Enum):
    PENDING = "PENDING"
    PROCESSING = "PROCESSING"
    NEEDS_REVIEW = "NEEDS_REVIEW"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"
    DLQ = "DLQ"
    COMPLETED_DUPLICATE = "COMPLETED_DUPLICATE"


class ReviewDecision(str, Enum):
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"
    NEEDS_REVISION = "NEEDS_REVISION"


class ParsedIngredient(BaseModel):
    """Ingredient as parsed from AI"""
    name: str = Field(..., min_length=1, max_length=200)
    quantity_value: Optional[float] = Field(None, ge=0)
    unit: Optional[str] = Field(None, max_length=50)
    notes: Optional[str] = Field(None, max_length=200)
    
    @validator('name')
    def validate_name(cls, v):
        return v.strip()
    
    @validator('unit')
    def normalize_unit(cls, v):
        if not v:
            return v
        # Normalize common units
        unit_map = {
            'tablespoon': 'tbsp', 'tablespoons': 'tbsp',
            'teaspoon': 'tsp', 'teaspoons': 'tsp',
            'grams': 'g', 'gram': 'g',
            'milliliters': 'ml', 'milliliter': 'ml',
            'kilograms': 'kg', 'kilogram': 'kg',
            'liters': 'l', 'liter': 'l',
            'ounces': 'oz', 'ounce': 'oz',
            'pounds': 'lb', 'pound': 'lb',
            'cups': 'cup',
            'pieces': 'piece', 'pcs': 'piece'
        }
        normalized = v.lower().strip()
        return unit_map.get(normalized, normalized)


class ParsedNutrition(BaseModel):
    """Nutrition information as parsed from AI"""
    calories_per_serving: Optional[int] = Field(None, ge=0)
    protein_g: Optional[float] = Field(None, ge=0)
    carbs_g: Optional[float] = Field(None, ge=0)
    fat_g: Optional[float] = Field(None, ge=0)
    sugar_g: Optional[float] = Field(None, ge=0)
    fiber_g: Optional[float] = Field(None, ge=0)
    sodium_mg: Optional[float] = Field(None, ge=0)


class ParsedRecipe(BaseModel):
    """Recipe as parsed from AI with all extracted fields"""
    title: str = Field(..., min_length=1, max_length=200)
    description: str = Field(..., min_length=1, max_length=1000)
    cuisine: str = Field(..., min_length=1, max_length=100)
    category: str = Field(..., min_length=1, max_length=100)
    difficulty: int = Field(..., ge=1, le=5)
    prep_time_minutes: int = Field(..., ge=0)
    cook_time_minutes: int = Field(..., ge=0)
    servings: int = Field(..., ge=1)
    ingredients: List[ParsedIngredient] = Field(..., min_items=1)
    instructions: List[str] = Field(..., min_items=1)
    tags: List[str] = Field(default_factory=list)
    nutrition: Optional[ParsedNutrition] = None
    
    # Metadata from parsing
    detected_language: Optional[str] = None
    was_translated: bool = False
    confidence_scores: Dict[str, float] = Field(default_factory=dict)
    
    @validator('title', 'description', 'cuisine', 'category')
    def strip_and_title_case(cls, v):
        return v.strip().title() if v else v
    
    @validator('instructions')
    def validate_instructions(cls, v):
        if not v or len(v) == 0:
            raise ValueError('At least one instruction is required')
        cleaned = []
        for i, instruction in enumerate(v):
            if not instruction.strip():
                raise ValueError(f'Instruction {i+1} cannot be empty')
            cleaned.append(instruction.strip())
        return cleaned
    
    @validator('tags')
    def normalize_tags(cls, v):
        if not v:
            return []
        # Normalize tags to lowercase and remove duplicates
        normalized = []
        seen = set()
        for tag in v:
            clean_tag = tag.strip().lower()
            if clean_tag and clean_tag not in seen:
                normalized.append(clean_tag)
                seen.add(clean_tag)
        return normalized
    
    @property
    def total_time_minutes(self) -> int:
        return self.prep_time_minutes + self.cook_time_minutes


class ExtractionMetadata(BaseModel):
    """Metadata about the extraction process"""
    file_size_bytes: int
    mime_type: str
    detected_language: Optional[str] = None
    extraction_method: str  # 'direct', 'ocr', 'pdf_parser', etc.
    ai_model_used: str
    token_usage: Dict[str, int] = Field(default_factory=dict)
    processing_time_seconds: float
    confidence_score: float = Field(..., ge=0.0, le=1.0)


class IngestionJobCreate(BaseModel):
    """Data for creating a new ingestion job"""
    source_path: str
    original_filename: str
    file_size_bytes: int
    mime_type: str


class IngestionJobUpdate(BaseModel):
    """Data for updating an ingestion job"""
    status: Optional[IngestionStatus] = None
    error_message: Optional[str] = None
    confidence_score: Optional[float] = Field(None, ge=0.0, le=1.0)
    recipe_id: Optional[UUID] = None
    duplicate_of_recipe_id: Optional[UUID] = None
    meta: Optional[Dict[str, Any]] = None
    processed_at: Optional[datetime] = None
    reviewed_at: Optional[datetime] = None
    reviewer_notes: Optional[str] = None


class IngestionJob(BaseModel):
    """Complete ingestion job model"""
    id: UUID
    source_path: str
    original_filename: Optional[str] = None
    file_size_bytes: Optional[int] = None
    mime_type: Optional[str] = None
    status: IngestionStatus
    error_message: Optional[str] = None
    retries: int = 0
    confidence_score: Optional[float] = None
    recipe_id: Optional[UUID] = None
    duplicate_of_recipe_id: Optional[UUID] = None
    meta: Optional[Dict[str, Any]] = None
    created_at: datetime
    updated_at: datetime
    processed_at: Optional[datetime] = None
    reviewed_at: Optional[datetime] = None
    reviewer_notes: Optional[str] = None
    
    class Config:
        from_attributes = True


class IngestionJobList(BaseModel):
    """List of ingestion jobs with pagination"""
    jobs: List[IngestionJob]
    total_count: int
    has_more: bool


class RecipeFingerprint(BaseModel):
    """Recipe fingerprint for duplicate detection"""
    recipe_id: UUID
    title_normalized: str
    cuisine_normalized: Optional[str] = None
    total_time_minutes: Optional[int] = None
    fingerprint_hash: str
    created_at: datetime
    
    class Config:
        from_attributes = True


class IngestionReview(BaseModel):
    """Manual review record"""
    id: UUID
    job_id: UUID
    reviewer_id: Optional[UUID] = None
    decision: ReviewDecision
    notes: Optional[str] = None
    created_at: datetime
    
    class Config:
        from_attributes = True


class IngestionStats(BaseModel):
    """Statistics about ingestion pipeline"""
    total_jobs: int
    pending_jobs: int
    processing_jobs: int
    needs_review_jobs: int
    completed_jobs: int
    failed_jobs: int
    dlq_jobs: int
    duplicate_jobs: int
    average_processing_time_seconds: Optional[float] = None
    success_rate: float
    review_rate: float


class ProcessingResult(BaseModel):
    """Result of processing a single file"""
    success: bool
    job_id: Optional[UUID] = None
    recipe_id: Optional[UUID] = None
    error_message: Optional[str] = None
    confidence_score: Optional[float] = None
    needs_review: bool = False
    is_duplicate: bool = False
    duplicate_of_recipe_id: Optional[UUID] = None
