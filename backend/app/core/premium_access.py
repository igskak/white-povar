"""
Premium access control dependencies and middleware
"""
from fastapi import HTTPException, Depends, status
from typing import Optional
import logging

from app.api.v1.endpoints.auth import verify_firebase_token, User
from app.services.subscription_service import subscription_service
from app.schemas.subscription import PremiumAccessCheck, UpgradePrompt

logger = logging.getLogger(__name__)


class PremiumAccessDenied(HTTPException):
    """Custom exception for premium access denial with upgrade prompt"""
    
    def __init__(
        self,
        detail: str = "Premium subscription required",
        upgrade_prompt: Optional[UpgradePrompt] = None
    ):
        super().__init__(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "premium_access_required",
                "message": detail,
                "upgrade_prompt": upgrade_prompt.dict() if upgrade_prompt else None,
            }
        )


async def require_premium_access(
    current_user: User = Depends(verify_firebase_token),
    feature: Optional[str] = None
) -> User:
    """
    Dependency to require premium access for an endpoint
    
    Args:
        current_user: Current authenticated user
        feature: Optional specific feature to check
        
    Returns:
        User if they have premium access
        
    Raises:
        PremiumAccessDenied: If user doesn't have premium access
    """
    access_check = await subscription_service.check_premium_access(
        user_id=current_user.id,
        feature=feature
    )
    
    if not access_check.has_access:
        logger.warning(
            f"Premium access denied for user {current_user.id}: {access_check.reason}"
        )
        
        # Determine appropriate upgrade prompt based on feature
        upgrade_prompt = _get_upgrade_prompt_for_feature(feature)
        
        raise PremiumAccessDenied(
            detail=access_check.reason or "Premium subscription required",
            upgrade_prompt=upgrade_prompt
        )
    
    return current_user


async def require_ai_access(
    current_user: User = Depends(verify_firebase_token)
) -> User:
    """
    Dependency specifically for AI features
    
    Args:
        current_user: Current authenticated user
        
    Returns:
        User if they have AI feature access
        
    Raises:
        PremiumAccessDenied: If user doesn't have AI access
    """
    return await require_premium_access(
        current_user=current_user,
        feature="ai_recipe_generation"
    )


async def get_user_with_subscription(
    current_user: User = Depends(verify_firebase_token)
) -> User:
    """
    Dependency to get user with subscription information attached
    
    Args:
        current_user: Current authenticated user
        
    Returns:
        User with subscription info populated
    """
    subscription_info = await subscription_service.get_user_subscription(current_user.id)
    
    # Attach subscription info to user object
    current_user.subscription = subscription_info
    
    return current_user


async def check_recipe_access(
    recipe_id: str,
    is_premium: bool,
    current_user: User = Depends(verify_firebase_token)
) -> bool:
    """
    Check if user can access a specific recipe
    
    Args:
        recipe_id: Recipe UUID
        is_premium: Whether the recipe is premium
        current_user: Current authenticated user
        
    Returns:
        True if user can access the recipe
        
    Raises:
        PremiumAccessDenied: If user cannot access premium recipe
    """
    if not is_premium:
        return True
    
    can_access = await subscription_service.can_access_recipe(
        user_id=current_user.id,
        is_premium_recipe=is_premium
    )
    
    if not can_access:
        logger.warning(
            f"User {current_user.id} attempted to access premium recipe {recipe_id}"
        )
        raise PremiumAccessDenied(
            detail="This is a premium recipe. Upgrade to access exclusive content.",
            upgrade_prompt=UpgradePrompt.get_premium_recipe_prompt()
        )
    
    return True


def _get_upgrade_prompt_for_feature(feature: Optional[str]) -> UpgradePrompt:
    """
    Get appropriate upgrade prompt based on feature
    
    Args:
        feature: Feature name
        
    Returns:
        UpgradePrompt with relevant messaging
    """
    if feature and "ai" in feature.lower():
        return UpgradePrompt.get_ai_feature_prompt()
    elif feature and "search" in feature.lower():
        return UpgradePrompt.get_advanced_search_prompt()
    else:
        return UpgradePrompt.get_premium_recipe_prompt()


# Helper function for filtering recipes based on subscription
async def filter_recipes_by_subscription(
    recipes: list,
    user_id: str,
    include_premium: bool = True
) -> list:
    """
    Filter recipes based on user's subscription tier

    Args:
        recipes: List of recipe dictionaries
        user_id: User UUID as string
        include_premium: Whether to include premium recipes in results

    Returns:
        Filtered list of recipes
    """
    logger.info(f"🔍 filter_recipes_by_subscription called for user: {user_id}")
    # Check if user has premium access
    access_check = await subscription_service.check_premium_access(user_id)
    has_premium = access_check.has_access
    logger.info(f"🔐 User premium access: {has_premium}, tier: {access_check.tier}")
    
    # If user has premium access, return all recipes
    if has_premium:
        logger.info(f"✅ User has premium, returning all {len(recipes)} recipes")
        return recipes

    # Filter out premium recipes for free users
    logger.info(f"🆓 User is free tier, filtering recipes (include_premium={include_premium})")
    filtered_recipes = []
    for recipe in recipes:
        is_premium = recipe.get('is_premium', False)

        # Free users can only see non-premium recipes
        if not is_premium:
            filtered_recipes.append(recipe)
        elif include_premium:
            # Optionally include premium recipes but mark them as locked
            recipe['_locked'] = True
            recipe['_requires_upgrade'] = True
            filtered_recipes.append(recipe)

    logger.info(f"📋 Filtered to {len(filtered_recipes)} recipes for free user")
    return filtered_recipes


# Decorator for premium-only endpoints
def premium_only(feature: Optional[str] = None):
    """
    Decorator to mark an endpoint as premium-only
    
    Usage:
        @router.get("/premium-endpoint")
        @premium_only(feature="ai_recipe_generation")
        async def my_endpoint(user: User = Depends(require_premium_access)):
            ...
    """
    def decorator(func):
        func._premium_only = True
        func._premium_feature = feature
        return func
    return decorator

