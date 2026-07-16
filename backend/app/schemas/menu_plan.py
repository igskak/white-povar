from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, Field


class MenuPlanSlotInput(BaseModel):
    planned_for: date
    recipe_id: str
    collection_id: str | None = None
    servings: int = Field(ge=1, le=100)
    position: int = Field(default=0, ge=0, le=1000)


class MenuPlanSlot(MenuPlanSlotInput):
    id: str
    title: str
    is_premium: bool = False
    image_url: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


class MenuPlanWeek(BaseModel):
    week_start: date
    slots: list[MenuPlanSlot] = Field(default_factory=list)


class MenuPlanReorder(BaseModel):
    slot_ids: list[str] = Field(min_length=1, max_length=100)


class MenuPlanShoppingRequest(BaseModel):
    week_start: date


class MenuPlanShare(BaseModel):
    week_start: date
    format: Literal['text'] = 'text'
