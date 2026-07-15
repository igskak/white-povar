"""Internal Creator Studio request and response contracts."""

from datetime import datetime

from typing import Literal

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


class StudioAssetUploadRequest(BaseModel):
    filename: str = Field(min_length=1, max_length=160)
    content_type: Literal['image/jpeg', 'image/png', 'image/webp'] = Field(alias='contentType')
    size_bytes: int = Field(alias='sizeBytes', gt=0, le=12 * 1024 * 1024)
    model_config = ConfigDict(populate_by_name=True)


class StudioAssetUploadTicket(BaseModel):
    asset_id: str = Field(alias='assetId')
    upload_url: str = Field(alias='uploadUrl')
    object_path: str = Field(alias='objectPath')
    expires_in_seconds: int = Field(alias='expiresInSeconds')
    model_config = ConfigDict(populate_by_name=True)


class StudioAssetFinalize(BaseModel):
    alt_text: str = Field(alias='altText', min_length=1, max_length=180)
    model_config = ConfigDict(populate_by_name=True)


class StudioAsset(BaseModel):
    id: str
    url: str | None = None
    alt_text: str = Field(alias='altText')
    width: int | None = None
    height: int | None = None
    state: str
    model_config = ConfigDict(populate_by_name=True)
