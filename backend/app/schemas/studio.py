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


# STUDIO-04 deliberately uses a separate internal contract.  Consumer recipe
# DTOs never gain draft/scheduling fields, so a draft cannot leak through a
# public endpoint by accident.
class StudioContentUpsert(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str = Field(min_length=1, max_length=1000)
    content_kind: Literal['recipe', 'technique', 'process', 'video'] = Field(alias='contentKind')
    cuisine: str = Field(default='Інше', min_length=1, max_length=100)
    category: str = Field(default='Інше', min_length=1, max_length=100)
    difficulty: int = Field(default=1, ge=1, le=5)
    prep_time_minutes: int = Field(default=0, alias='prepTimeMinutes', ge=0)
    cook_time_minutes: int = Field(default=0, alias='cookTimeMinutes', ge=0)
    servings: int = Field(default=1, ge=1)
    instructions: list[str] = Field(default_factory=list)
    images: list[str] = Field(default_factory=list)
    video_url: str | None = Field(default=None, alias='videoUrl', max_length=1000)
    video_file_path: str | None = Field(default=None, alias='videoFilePath', max_length=1000)
    tags: list[str] = Field(default_factory=list)
    is_featured: bool = Field(default=False, alias='isFeatured')
    is_premium: bool = Field(default=False, alias='isPremium')
    publish_at: datetime | None = Field(default=None, alias='publishAt')
    model_config = ConfigDict(populate_by_name=True)

    @model_validator(mode='after')
    def validate_kind(self):
        if self.content_kind == 'recipe' and not self.instructions:
            raise ValueError('Recipe content requires at least one instruction')
        if self.content_kind == 'video' and not (self.video_url or self.video_file_path):
            raise ValueError('Video content requires videoUrl or videoFilePath')
        return self


class StudioCollectionItemInput(BaseModel):
    recipe_id: str = Field(alias='recipeId')
    is_preview: bool = Field(default=False, alias='isPreview')
    model_config = ConfigDict(populate_by_name=True)


class StudioCollectionUpsert(BaseModel):
    slug: str = Field(pattern=r'^[a-z0-9]+(?:-[a-z0-9]+)*$', max_length=120)
    title_i18n: dict[str, str] = Field(alias='titleI18n')
    description_i18n: dict[str, str] = Field(default_factory=dict, alias='descriptionI18n')
    cover_url: str | None = Field(default=None, alias='coverUrl', max_length=1000)
    is_premium: bool = Field(default=False, alias='isPremium')
    items: list[StudioCollectionItemInput] = Field(default_factory=list)
    publish_at: datetime | None = Field(default=None, alias='publishAt')
    model_config = ConfigDict(populate_by_name=True)

    @model_validator(mode='after')
    def ukrainian_title_and_unique_items(self):
        if not self.title_i18n.get('uk', '').strip():
            raise ValueError('titleI18n.uk is required')
        ids = [item.recipe_id for item in self.items]
        if len(ids) != len(set(ids)):
            raise ValueError('A material can appear only once in a collection')
        return self


class StudioMerchandisingUpsert(BaseModel):
    product_key: str = Field(alias='productKey', min_length=1, max_length=120)
    kind: Literal['subscription', 'one_off']
    offer_key: str = Field(alias='offerKey', min_length=1, max_length=120)
    collection_id: str | None = Field(default=None, alias='collectionId')
    active: bool = False
    model_config = ConfigDict(populate_by_name=True)

    @model_validator(mode='after')
    def one_off_requires_collection(self):
        if self.kind == 'one_off' and not self.collection_id:
            raise ValueError('collectionId is required for a one-off product')
        if self.kind == 'subscription' and self.collection_id:
            raise ValueError('collectionId is not valid for a subscription')
        return self
