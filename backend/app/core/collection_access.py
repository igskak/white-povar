"""One collection access decision point, ready for COM-01 scoped products."""
from dataclasses import dataclass
from typing import Any, Optional

from app.api.v1.endpoints.auth import User
from app.core.tenant import TenantContext
from app.services.subscription_service import subscription_service


@dataclass(frozen=True)
class CollectionAccess:
    exists_in_tenant: bool
    can_read_items: bool


async def resolve_collection_access(
    collection: dict[str, Any], tenant: TenantContext, user: Optional[User],
) -> CollectionAccess:
    """Resolve a collection without accepting client product or ownership claims.

    COL-02 recognizes the existing tenant subscription entitlement. COM-01 will
    extend this single boundary with product-to-collection one-off scopes; it
    must not be duplicated in a route or client.
    """
    if str(collection.get('chef_id')) != tenant.chef_id:
        return CollectionAccess(False, False)

    is_member = user is not None and user.chef_id == tenant.chef_id
    if not collection.get('is_premium', False) or is_member:
        return CollectionAccess(True, True)
    if user is None:
        return CollectionAccess(True, False)
    allowed = await subscription_service.has_tenant_entitlement(user.id, tenant.chef_id)
    return CollectionAccess(True, allowed)
