from typing import List, Optional

from pydantic import BaseModel, Field, validator


class PreferenceProfile(BaseModel):
    diets: List[str] = Field(default_factory=list, max_items=12)
    allergens: List[str] = Field(default_factory=list, max_items=24)
    dislikes: List[str] = Field(default_factory=list, max_items=24)
    preferred_max_total_time: Optional[int] = Field(None, ge=1, le=1440)
    equipment: List[str] = Field(default_factory=list, max_items=24)
    household_size: Optional[int] = Field(None, ge=1, le=30)
    personalization_consent: bool

    @validator('diets', 'allergens', 'dislikes', 'equipment')
    def normalize_values(cls, value):
        normalized = []
        for item in value:
            item = item.strip().lower()
            if item and item not in normalized:
                normalized.append(item)
        return normalized


class StoredPreferenceProfile(PreferenceProfile):
    updated_at: Optional[str] = None
