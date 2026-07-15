"""Consumer contracts for tenant-scoped, ordered content collections."""
from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, Field

from app.schemas.recipe import Recipe


class CollectionItem(BaseModel):
    """A reusable content item at one stable position in a collection."""

    id: UUID
    position: int = Field(ge=0)
    is_preview: bool = False
    content: Recipe


class CollectionSummary(BaseModel):
    id: UUID
    chef_id: UUID
    slug: str
    title: str
    description: str
    cover_url: Optional[str] = None
    is_premium: bool = False
    is_locked: bool = False
    item_count: int = Field(ge=0)
    published_at: Optional[datetime] = None


class CollectionDetail(CollectionSummary):
    items: List[CollectionItem] = Field(default_factory=list)


class CollectionList(BaseModel):
    collections: List[CollectionSummary]
    total_count: int = Field(ge=0)
    has_more: bool = False
