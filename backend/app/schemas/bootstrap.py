"""Public runtime bootstrap contract for a tenant application."""

from typing import Any, Dict
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class BootstrapTenant(BaseModel):
    id: UUID
    slug: str


class TenantBootstrap(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    tenant: BootstrapTenant
    brand_config: Dict[str, Any] = Field(alias="brandConfig")
    product_config: Dict[str, Any] = Field(alias="productConfig")
    config_version: str = Field(alias="configVersion")
