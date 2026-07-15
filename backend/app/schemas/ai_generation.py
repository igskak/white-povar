"""Contracts for the opt-in, non-persistent AI recipe flow."""
from typing import Literal

from pydantic import BaseModel, Field


class RecipeGenerationRequest(BaseModel):
    prompt: str = Field(..., min_length=2, max_length=500)
    generation_consent: Literal[True] = Field(
        ..., description="A separate, per-request opt-in is required."
    )
    available_ingredients: list[str] = Field(default_factory=list, max_length=12)
    dietary_restrictions: list[str] = Field(default_factory=list, max_length=12)
    allergens: list[str] = Field(default_factory=list, max_length=24)


class GeneratedIngredient(BaseModel):
    name: str = Field(..., min_length=1, max_length=80)
    amount: str = Field(..., min_length=1, max_length=40)


class GeneratedRecipe(BaseModel):
    """A preview only; AI-02 owns private persistence and editing."""

    source: Literal['ai_generated'] = 'ai_generated'
    title: str = Field(..., min_length=1, max_length=120)
    description: str = Field(..., min_length=1, max_length=500)
    servings: int = Field(..., ge=1, le=30)
    total_time_minutes: int = Field(..., ge=1, le=1440)
    ingredients: list[GeneratedIngredient] = Field(..., min_length=1, max_length=30)
    steps: list[str] = Field(..., min_length=1, max_length=16)
    safety_note: str = Field(..., min_length=1, max_length=280)
    attribution: Literal['Створено AI, не опублікований рецепт автора'] = (
        'Створено AI, не опублікований рецепт автора'
    )
