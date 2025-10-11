"""
Subscription management endpoints
"""
from fastapi import APIRouter, HTTPException, Depends, status
from typing import Optional
import logging

from app.api.v1.endpoints.auth import verify_firebase_token, User
from app.services.subscription_service import subscription_service
from app.schemas.subscription import (
    SubscriptionStatusResponse,
    SubscriptionUpdateRequest,
    PremiumAccessCheck,
    UpgradePrompt,
    SubscriptionFeatures,
    SubscriptionTier,
)

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/status", response_model=SubscriptionStatusResponse)
async def get_subscription_status(
    current_user: User = Depends(verify_firebase_token)
):
    """
    Get current user's subscription status and available features
    """
    try:
        status_response = await subscription_service.get_subscription_status(current_user.id)
        return status_response
        
    except Exception as e:
        logger.error(f"Error getting subscription status: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get subscription status"
        )


@router.get("/check-access", response_model=PremiumAccessCheck)
async def check_premium_access(
    feature: Optional[str] = None,
    current_user: User = Depends(verify_firebase_token)
):
    """
    Check if user has premium access (optionally for a specific feature)
    
    Query Parameters:
        feature: Optional feature name to check (e.g., 'ai_recipe_generation')
    """
    try:
        access_check = await subscription_service.check_premium_access(
            user_id=current_user.id,
            feature=feature
        )
        return access_check
        
    except Exception as e:
        logger.error(f"Error checking premium access: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to check premium access"
        )


@router.get("/features", response_model=dict)
async def get_available_features(
    current_user: User = Depends(verify_firebase_token)
):
    """
    Get list of features available to the current user based on their subscription tier
    """
    try:
        subscription_info = await subscription_service.get_user_subscription(current_user.id)
        
        if not subscription_info:
            # Default to free tier
            tier = SubscriptionTier.FREE
        else:
            tier = subscription_info.tier
        
        features = SubscriptionFeatures.get_features(tier)
        
        return {
            "tier": tier.value,
            "features": features
        }
        
    except Exception as e:
        logger.error(f"Error getting available features: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get available features"
        )


@router.get("/upgrade-prompts/{prompt_type}", response_model=UpgradePrompt)
async def get_upgrade_prompt(prompt_type: str):
    """
    Get upgrade prompt for a specific feature type
    
    Path Parameters:
        prompt_type: Type of prompt ('ai_features', 'premium_recipes', 'advanced_search')
    """
    try:
        if prompt_type == "ai_features":
            return UpgradePrompt.get_ai_feature_prompt()
        elif prompt_type == "premium_recipes":
            return UpgradePrompt.get_premium_recipe_prompt()
        elif prompt_type == "advanced_search":
            return UpgradePrompt.get_advanced_search_prompt()
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unknown prompt type: {prompt_type}"
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting upgrade prompt: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get upgrade prompt"
        )


@router.put("/update", response_model=dict)
async def update_subscription(
    update_request: SubscriptionUpdateRequest,
    current_user: User = Depends(verify_firebase_token)
):
    """
    Update user subscription (for admin/testing purposes)
    
    Note: In production, this should be called by payment webhooks, not directly by users
    """
    try:
        success = await subscription_service.update_subscription(
            user_id=current_user.id,
            tier=update_request.tier,
            status=update_request.status,
            end_date=update_request.end_date
        )
        
        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to update subscription"
            )
        
        # Get updated subscription status
        updated_status = await subscription_service.get_subscription_status(current_user.id)
        
        return {
            "success": True,
            "message": "Subscription updated successfully",
            "subscription": updated_status.dict()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating subscription: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update subscription"
        )


@router.post("/grant-premium", response_model=dict)
async def grant_premium(
    duration_days: int = 30,
    current_user: User = Depends(verify_firebase_token)
):
    """
    Grant premium access to user (for testing/admin purposes)
    
    Query Parameters:
        duration_days: Number of days to grant premium access (default: 30)
    """
    try:
        success = await subscription_service.grant_premium_access(
            user_id=current_user.id,
            duration_days=duration_days
        )
        
        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to grant premium access"
            )
        
        return {
            "success": True,
            "message": f"Premium access granted for {duration_days} days",
            "duration_days": duration_days
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error granting premium access: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to grant premium access"
        )


@router.post("/revoke-premium", response_model=dict)
async def revoke_premium(
    current_user: User = Depends(verify_firebase_token)
):
    """
    Revoke premium access from user (for testing/admin purposes)
    """
    try:
        success = await subscription_service.revoke_premium_access(current_user.id)
        
        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to revoke premium access"
            )
        
        return {
            "success": True,
            "message": "Premium access revoked"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error revoking premium access: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to revoke premium access"
        )


@router.get("/tiers", response_model=dict)
async def get_subscription_tiers():
    """
    Get information about available subscription tiers and their features
    """
    try:
        return {
            "tiers": [
                {
                    "name": "free",
                    "display_name": "Free",
                    "price": 0,
                    "currency": "UAH",
                    "features": SubscriptionFeatures.get_features(SubscriptionTier.FREE)
                },
                {
                    "name": "premium",
                    "display_name": "Premium",
                    "price": 99,  # Placeholder price in UAH
                    "currency": "UAH",
                    "features": SubscriptionFeatures.get_features(SubscriptionTier.PREMIUM)
                }
            ]
        }
        
    except Exception as e:
        logger.error(f"Error getting subscription tiers: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get subscription tiers"
        )

