"""Internal Creator Studio request and response contracts."""

from datetime import datetime

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

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


ReleaseKind = Literal['web_deploy', 'mobile_build']
ReleaseStatus = Literal['queued', 'running', 'succeeded', 'failed']
StoreReleaseStatus = Literal['not_submitted', 'pending', 'released', 'rejected']


class StudioPublishResult(BaseModel):
    version: int
    published_at: datetime = Field(alias='publishedAt')
    model_config = ConfigDict(populate_by_name=True)


class StudioRollbackRequest(BaseModel):
    source_version: int = Field(alias='sourceVersion', ge=1)
    model_config = ConfigDict(populate_by_name=True)


class StudioReleaseRequest(BaseModel):
    kind: ReleaseKind
    platform: Literal['android', 'ios'] | None = None

    @model_validator(mode='after')
    def mobile_requires_platform(self):
        if self.kind == 'mobile_build' and self.platform is None:
            raise ValueError('platform is required for a mobile build')
        if self.kind == 'web_deploy' and self.platform is not None:
            raise ValueError('platform is only valid for a mobile build')
        return self


class StudioReleaseUpdate(BaseModel):
    status: ReleaseStatus
    store_release_status: StoreReleaseStatus | None = Field(default=None, alias='storeReleaseStatus')
    failure_reason: str | None = Field(default=None, alias='failureReason', max_length=300)
    model_config = ConfigDict(populate_by_name=True)

    @model_validator(mode='after')
    def failure_has_reason(self):
        if self.status == 'failed' and not self.failure_reason:
            raise ValueError('failureReason is required for failed releases')
        return self


class StudioRelease(BaseModel):
    id: str
    kind: ReleaseKind
    status: ReleaseStatus
    platform: str | None = None
    config_version: int = Field(alias='configVersion')
    store_release_status: StoreReleaseStatus = Field(alias='storeReleaseStatus')
    failure_reason: str | None = Field(default=None, alias='failureReason')
    requested_at: datetime = Field(alias='requestedAt')
    updated_at: datetime = Field(alias='updatedAt')
    model_config = ConfigDict(populate_by_name=True)


class StudioReleaseStatusView(BaseModel):
    config_published: StudioPublishResult | None = Field(alias='configPublished')
    web_deployed: StudioRelease | None = Field(alias='webDeployed')
    mobile_build: StudioRelease | None = Field(alias='mobileBuild')
    store_release: StudioRelease | None = Field(alias='storeRelease')
    history: list[StudioRelease]
    model_config = ConfigDict(populate_by_name=True)
