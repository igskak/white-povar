"""One access decision point for recipe details and teaser projection."""
from dataclasses import dataclass
from typing import Any, Optional

from app.api.v1.endpoints.auth import User
from app.core.tenant import TenantContext
from app.services.database import supabase_service
from app.services.subscription_service import subscription_service


@dataclass(frozen=True)
class RecipeAccess:
    exists_in_tenant: bool
    can_read_body: bool


async def resolve_recipe_access(
    recipe: dict[str, Any], tenant: TenantContext, user: Optional[User],
) -> RecipeAccess:
    """Fail closed for a cross-tenant ID, private row, or missing entitlement."""
    if str(recipe.get("chef_id")) != tenant.chef_id:
        return RecipeAccess(False, False)

    is_member = user is not None and user.chef_id == tenant.chef_id
    if not recipe.get("is_public", False) and not is_member:
        return RecipeAccess(False, False)
    if not recipe.get("is_premium", False) or is_member:
        return RecipeAccess(True, True)
    if user is None:
        return RecipeAccess(True, False)
    allowed = await subscription_service.has_tenant_entitlement(user.id, tenant.chef_id)
    return RecipeAccess(True, allowed)


async def resolve_preview_grant(
    recipe: dict[str, Any], collection_id: str, tenant: TenantContext,
) -> bool:
    """Open one premium recipe because a collection marked it a free preview.

    The collection claim arrives from the client, so it is never trusted on its
    own: the row is re-read server-side, and a grant opens only the recipe it
    names, never the rest of that collection.
    """
    if str(recipe.get("chef_id")) != tenant.chef_id or not recipe.get("is_public", False):
        return False
    return await supabase_service.collection_grants_preview(
        str(recipe.get("id")), collection_id, tenant.chef_id,
    )
