"""
Subscription service for managing premium access and subscription lifecycle
"""
import logging
from typing import Optional, Dict, Any
from datetime import datetime, timedelta
from uuid import UUID

from app.schemas.subscription import (
    SubscriptionTier,
    SubscriptionStatus,
    UserSubscriptionInfo,
    SubscriptionStatusResponse,
    PremiumAccessCheck,
    SubscriptionFeatures,
)
from app.services.database import supabase_service

logger = logging.getLogger(__name__)


class SubscriptionService:
    """Service for managing user subscriptions and premium access"""
    
    def __init__(self):
        self.db_service = supabase_service
    
    async def get_user_subscription(self, user_id: str) -> Optional[UserSubscriptionInfo]:
        """
        Get user's subscription information
        
        Args:
            user_id: User UUID as string
            
        Returns:
            UserSubscriptionInfo or None if user not found
        """
        try:
            result = await self.db_service.execute_query(
                'users',
                'select',
                filters={'id': user_id}
            )
            
            if not result.data or len(result.data) == 0:
                logger.warning(f"User not found: {user_id}")
                return None
            
            user_data = result.data[0]
            
            # Parse subscription data
            subscription_info = UserSubscriptionInfo(
                tier=SubscriptionTier(user_data.get('subscription_tier', 'free')),
                status=SubscriptionStatus(user_data.get('subscription_status', 'active')),
                start_date=self._parse_datetime(user_data.get('subscription_start_date')),
                end_date=self._parse_datetime(user_data.get('subscription_end_date')),
            )
            
            return subscription_info
            
        except Exception as e:
            logger.error(f"Error getting user subscription: {str(e)}")
            return None
    
    async def get_subscription_status(self, user_id: str) -> SubscriptionStatusResponse:
        """
        Get complete subscription status with features
        
        Args:
            user_id: User UUID as string
            
        Returns:
            SubscriptionStatusResponse with subscription info and available features
        """
        subscription = await self.get_user_subscription(user_id)
        
        if not subscription:
            # Return default free tier for unknown users
            subscription = UserSubscriptionInfo(
                tier=SubscriptionTier.FREE,
                status=SubscriptionStatus.ACTIVE,
            )
        
        has_premium = self._check_premium_access(subscription)
        
        return SubscriptionStatusResponse(
            user_id=UUID(user_id),
            subscription=subscription,
            has_premium_access=has_premium,
        )
    
    async def check_premium_access(self, user_id: str, feature: Optional[str] = None) -> PremiumAccessCheck:
        """
        Check if user has premium access
        
        Args:
            user_id: User UUID as string
            feature: Optional specific feature to check (e.g., 'ai_recipe_generation')
            
        Returns:
            PremiumAccessCheck with access status and details
        """
        subscription = await self.get_user_subscription(user_id)
        
        if not subscription:
            return PremiumAccessCheck(
                has_access=False,
                tier=SubscriptionTier.FREE,
                reason="User not found or no subscription",
            )
        
        has_access = self._check_premium_access(subscription)
        
        # If checking specific feature, verify it's available
        if feature and has_access:
            features = SubscriptionFeatures.get_features(subscription.tier)
            has_access = features.get(feature, False)
            
            if not has_access:
                return PremiumAccessCheck(
                    has_access=False,
                    tier=subscription.tier,
                    reason=f"Feature '{feature}' not available in {subscription.tier.value} tier",
                )
        
        return PremiumAccessCheck(
            has_access=has_access,
            tier=subscription.tier,
            reason=None if has_access else self._get_access_denial_reason(subscription),
        )
    
    async def update_subscription(
        self,
        user_id: str,
        tier: Optional[SubscriptionTier] = None,
        status: Optional[SubscriptionStatus] = None,
        end_date: Optional[datetime] = None,
    ) -> bool:
        """
        Update user subscription (for admin/testing purposes)
        
        Args:
            user_id: User UUID as string
            tier: New subscription tier
            status: New subscription status
            end_date: New end date
            
        Returns:
            True if successful, False otherwise
        """
        try:
            update_data: Dict[str, Any] = {
                'subscription_updated_at': datetime.utcnow().isoformat(),
            }
            
            if tier is not None:
                update_data['subscription_tier'] = tier.value
                
                # If upgrading to premium, set start date if not already set
                if tier == SubscriptionTier.PREMIUM:
                    current_sub = await self.get_user_subscription(user_id)
                    if not current_sub or not current_sub.start_date:
                        update_data['subscription_start_date'] = datetime.utcnow().isoformat()
            
            if status is not None:
                update_data['subscription_status'] = status.value
            
            if end_date is not None:
                update_data['subscription_end_date'] = end_date.isoformat()
            
            result = await self.db_service.execute_query(
                'users',
                'update',
                filters={'id': user_id},
                data=update_data,
                use_service_key=True
            )
            
            if result.data:
                logger.info(f"Updated subscription for user {user_id}: {update_data}")
                return True
            
            return False
            
        except Exception as e:
            logger.error(f"Error updating subscription: {str(e)}")
            return False
    
    async def grant_premium_access(
        self,
        user_id: str,
        duration_days: int = 30,
        auto_renew: bool = False
    ) -> bool:
        """
        Grant premium access to a user
        
        Args:
            user_id: User UUID as string
            duration_days: Number of days for premium access
            auto_renew: Whether subscription should auto-renew
            
        Returns:
            True if successful, False otherwise
        """
        start_date = datetime.utcnow()
        end_date = start_date + timedelta(days=duration_days)
        
        return await self.update_subscription(
            user_id=user_id,
            tier=SubscriptionTier.PREMIUM,
            status=SubscriptionStatus.ACTIVE,
            end_date=end_date,
        )
    
    async def revoke_premium_access(self, user_id: str) -> bool:
        """
        Revoke premium access from a user
        
        Args:
            user_id: User UUID as string
            
        Returns:
            True if successful, False otherwise
        """
        return await self.update_subscription(
            user_id=user_id,
            tier=SubscriptionTier.FREE,
            status=SubscriptionStatus.ACTIVE,
        )
    
    async def can_access_recipe(self, user_id: str, is_premium_recipe: bool) -> bool:
        """
        Check if user can access a specific recipe
        
        Args:
            user_id: User UUID as string
            is_premium_recipe: Whether the recipe is premium
            
        Returns:
            True if user can access the recipe, False otherwise
        """
        # Free recipes are accessible to everyone
        if not is_premium_recipe:
            return True
        
        # Premium recipes require premium access
        access_check = await self.check_premium_access(user_id)
        return access_check.has_access
    
    def _check_premium_access(self, subscription: UserSubscriptionInfo) -> bool:
        """
        Internal method to check if subscription grants premium access
        
        Args:
            subscription: User subscription info
            
        Returns:
            True if user has active premium access
        """
        # Must be premium tier
        if subscription.tier != SubscriptionTier.PREMIUM:
            return False
        
        # Must have active status
        if subscription.status != SubscriptionStatus.ACTIVE:
            return False
        
        # Check if subscription has expired
        if subscription.end_date and subscription.end_date < datetime.utcnow():
            return False
        
        return True
    
    def _get_access_denial_reason(self, subscription: UserSubscriptionInfo) -> str:
        """
        Get human-readable reason for access denial
        
        Args:
            subscription: User subscription info
            
        Returns:
            Reason string
        """
        if subscription.tier == SubscriptionTier.FREE:
            return "Premium subscription required"
        
        if subscription.status == SubscriptionStatus.EXPIRED:
            return "Subscription has expired"
        
        if subscription.status == SubscriptionStatus.CANCELLED:
            return "Subscription has been cancelled"
        
        if subscription.end_date and subscription.end_date < datetime.utcnow():
            return "Subscription period has ended"
        
        return "Premium access not available"
    
    def _parse_datetime(self, value: Any) -> Optional[datetime]:
        """
        Parse datetime from various formats
        
        Args:
            value: Datetime value (string, datetime, or None)
            
        Returns:
            Parsed datetime or None
        """
        if value is None:
            return None
        
        if isinstance(value, datetime):
            return value
        
        if isinstance(value, str):
            try:
                # Try ISO format
                return datetime.fromisoformat(value.replace('Z', '+00:00'))
            except Exception:
                logger.warning(f"Failed to parse datetime: {value}")
                return None
        
        return None


# Global instance
subscription_service = SubscriptionService()

