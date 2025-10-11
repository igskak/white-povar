"""
Subscription schemas for premium content access system
"""
from pydantic import BaseModel, Field, validator
from typing import Optional, Literal
from datetime import datetime
from uuid import UUID
from enum import Enum


class SubscriptionTier(str, Enum):
    """Subscription tier enumeration"""
    FREE = "free"
    PREMIUM = "premium"


class SubscriptionStatus(str, Enum):
    """Subscription status enumeration"""
    ACTIVE = "active"
    EXPIRED = "expired"
    CANCELLED = "cancelled"
    TRIAL = "trial"


class SubscriptionBase(BaseModel):
    """Base subscription model"""
    tier: SubscriptionTier
    status: SubscriptionStatus
    start_date: datetime
    end_date: datetime
    auto_renew: bool = True
    
    @validator('end_date')
    def validate_end_date(cls, v, values):
        """Ensure end_date is after start_date"""
        if 'start_date' in values and v <= values['start_date']:
            raise ValueError('end_date must be after start_date')
        return v


class SubscriptionCreate(SubscriptionBase):
    """Schema for creating a new subscription"""
    user_id: UUID
    payment_provider: Optional[str] = None
    payment_id: Optional[str] = None
    payment_amount: Optional[float] = Field(None, gt=0)
    payment_currency: str = "UAH"


class Subscription(SubscriptionBase):
    """Complete subscription model"""
    id: UUID
    user_id: UUID
    payment_provider: Optional[str] = None
    payment_id: Optional[str] = None
    payment_amount: Optional[float] = None
    payment_currency: str = "UAH"
    cancelled_at: Optional[datetime] = None
    cancellation_reason: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class UserSubscriptionInfo(BaseModel):
    """User subscription information (embedded in user model)"""
    tier: SubscriptionTier = SubscriptionTier.FREE
    status: SubscriptionStatus = SubscriptionStatus.ACTIVE
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    is_active: bool = False
    
    @validator('is_active', always=True)
    def calculate_is_active(cls, v, values):
        """Calculate if subscription is currently active"""
        if values.get('tier') == SubscriptionTier.FREE:
            return True  # Free tier is always "active"
        
        if values.get('status') != SubscriptionStatus.ACTIVE:
            return False
        
        # Check if subscription has expired
        end_date = values.get('end_date')
        if end_date and end_date < datetime.utcnow():
            return False
        
        return True
    
    class Config:
        from_attributes = True


class SubscriptionStatusResponse(BaseModel):
    """Response model for subscription status check"""
    user_id: UUID
    subscription: UserSubscriptionInfo
    has_premium_access: bool
    features: dict = Field(default_factory=dict)
    
    @validator('features', always=True)
    def set_features(cls, v, values):
        """Set available features based on subscription tier"""
        subscription = values.get('subscription')
        if not subscription:
            return v
        
        is_premium = subscription.tier == SubscriptionTier.PREMIUM and subscription.is_active
        
        return {
            "ai_recipe_generation": is_premium,
            "ai_cooking_tips": is_premium,
            "ai_substitutions": is_premium,
            "ai_nutrition_analysis": is_premium,
            "premium_recipes": is_premium,
            "advanced_search": is_premium,
            "basic_recipes": True,  # Always available
            "basic_search": True,   # Always available
            "favorites": True,      # Always available
        }


class SubscriptionUpdateRequest(BaseModel):
    """Request to update subscription (for admin/testing)"""
    tier: Optional[SubscriptionTier] = None
    status: Optional[SubscriptionStatus] = None
    end_date: Optional[datetime] = None


class PremiumAccessCheck(BaseModel):
    """Response for premium access validation"""
    has_access: bool
    tier: SubscriptionTier
    reason: Optional[str] = None
    upgrade_required: bool = False
    
    @validator('upgrade_required', always=True)
    def set_upgrade_required(cls, v, values):
        """Set upgrade_required based on has_access"""
        return not values.get('has_access', False)


class SubscriptionEvent(BaseModel):
    """Subscription event for audit log"""
    id: UUID
    user_id: UUID
    subscription_id: Optional[UUID] = None
    event_type: str
    old_tier: Optional[SubscriptionTier] = None
    new_tier: Optional[SubscriptionTier] = None
    old_status: Optional[SubscriptionStatus] = None
    new_status: Optional[SubscriptionStatus] = None
    triggered_by: str
    metadata: dict = Field(default_factory=dict)
    created_at: datetime
    
    class Config:
        from_attributes = True


class SubscriptionFeatures(BaseModel):
    """Available features for each subscription tier"""
    tier: SubscriptionTier
    features: dict
    
    @staticmethod
    def get_features(tier: SubscriptionTier) -> dict:
        """Get features for a specific tier"""
        if tier == SubscriptionTier.PREMIUM:
            return {
                "ai_recipe_generation": True,
                "ai_cooking_tips": True,
                "ai_substitutions": True,
                "ai_nutrition_analysis": True,
                "premium_recipes": True,
                "advanced_search": True,
                "basic_recipes": True,
                "basic_search": True,
                "favorites": True,
                "max_favorites": None,  # Unlimited
            }
        else:  # FREE
            return {
                "ai_recipe_generation": False,
                "ai_cooking_tips": False,
                "ai_substitutions": False,
                "ai_nutrition_analysis": False,
                "premium_recipes": False,
                "advanced_search": False,
                "basic_recipes": True,
                "basic_search": True,
                "favorites": True,
                "max_favorites": 50,  # Limited for free tier
            }


class UpgradePrompt(BaseModel):
    """Upgrade prompt information for frontend"""
    title: str = "Upgrade to Premium"
    message: str
    features: list[str]
    cta_text: str = "Upgrade Now"
    
    @staticmethod
    def get_ai_feature_prompt() -> "UpgradePrompt":
        """Get upgrade prompt for AI features"""
        return UpgradePrompt(
            message="AI-powered recipe generation is a premium feature",
            features=[
                "Generate unlimited recipes with AI",
                "Get personalized cooking tips",
                "Smart ingredient substitutions",
                "Detailed nutrition analysis",
                "Access to 500+ premium recipes"
            ]
        )
    
    @staticmethod
    def get_premium_recipe_prompt() -> "UpgradePrompt":
        """Get upgrade prompt for premium recipes"""
        return UpgradePrompt(
            message="This is a premium recipe from professional chefs",
            features=[
                "Access 500+ premium recipes",
                "Exclusive content from verified chefs",
                "AI-powered cooking assistant",
                "Advanced search and filtering",
                "Unlimited favorites"
            ]
        )
    
    @staticmethod
    def get_advanced_search_prompt() -> "UpgradePrompt":
        """Get upgrade prompt for advanced search"""
        return UpgradePrompt(
            message="Search across all recipes with premium access",
            features=[
                "Search premium and basic recipes",
                "Advanced filtering options",
                "AI-powered recipe suggestions",
                "Save unlimited favorites",
                "Access exclusive chef content"
            ]
        )

