"""One collection access decision point for subscription and one-off products."""
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

    Product ownership is resolved only by the server entitlement service; a
    one-off grant is accepted only when the product is mapped to this collection.
    """
    if str(collection.get('chef_id')) != tenant.chef_id:
        return CollectionAccess(False, False)

    is_member = user is not None and user.chef_id == tenant.chef_id
    if not collection.get('is_premium', False) or is_member:
        return CollectionAccess(True, True)
    if user is None:
        return CollectionAccess(True, False)
    allowed = await subscription_service.has_collection_entitlement(
        user.id, tenant.chef_id, str(collection.get('id')),
    )
    return CollectionAccess(True, allowed)
