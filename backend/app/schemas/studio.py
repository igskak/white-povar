"""Internal Creator Studio request and response contracts."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.brand_config import BrandConfig


class StudioSession(BaseModel):
    role: str
    tenant_slug: str = Field(alias='tenantSlug')
    model_config = ConfigDict(populate_by_name=True)


class StudioBrandDraft(BaseModel):
    config: BrandConfig
    version: int
    updated_at: datetime | None = Field(default=None, alias='updatedAt')
    model_config = ConfigDict(populate_by_name=True)


class StudioBrandDraftUpdate(BaseModel):
    config: BrandConfig
    expected_version: int = Field(alias='expectedVersion', ge=1)
    model_config = ConfigDict(populate_by_name=True)
