"""Trusted, request-scoped tenant resolution.

The client header selects a public tenant catalogue; it is never an authority
claim.  Every tenant-aware handler receives this resolved context instead of a
caller-supplied chef id.
"""
from dataclasses import dataclass

from fastapi import Header, HTTPException, status

from app.services.database import supabase_service


@dataclass(frozen=True)
class TenantContext:
    chef_id: str
    slug: str


async def require_tenant_context(
    tenant_slug: str | None = Header(None, alias="X-Tenant-Slug"),
) -> TenantContext:
    if not tenant_slug:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="X-Tenant-Slug is required")

    tenant = await supabase_service.get_active_tenant(tenant_slug)
    if tenant is None:
        # Do not distinguish inactive from unknown tenants.
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tenant not found")
    return TenantContext(chef_id=str(tenant["id"]), slug=str(tenant["slug"]))
