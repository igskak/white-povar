from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field, field_validator


class PantryItemInput(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    quantity: Optional[float] = Field(None, gt=0, le=100000)
    unit: Optional[str] = Field(None, max_length=24)
    freshness_date: Optional[datetime] = None
    source: str = Field('manual', pattern='^(manual|camera|voice)$')
    confidence: Optional[float] = Field(None, ge=0, le=1)
    confirmed: bool = True

    @field_validator('name', 'unit')
    @classmethod
    def clean_text(cls, value):
        return value.strip().lower() if value else value


class PantryItem(PantryItemInput):
    id: str
    updated_at: Optional[datetime] = None


class ShoppingListItemInput(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    quantity: Optional[float] = Field(None, gt=0, le=100000)
    unit: Optional[str] = Field(None, max_length=24)
    category: str = Field('Інше', max_length=60)
    recipe_id: Optional[str] = None
    checked: bool = False


class ShoppingListItem(ShoppingListItemInput):
    id: str
    updated_at: Optional[datetime] = None


class RecipeShoppingRequest(BaseModel):
    servings: int = Field(gt=0, le=100)


class ShoppingList(BaseModel):
    items: List[ShoppingListItem] = Field(default_factory=list)

