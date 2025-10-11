# Premium Content Access System - Backend Implementation

## Overview
This document describes the backend implementation of the premium content access system for the White Povar recipe application.

## System Architecture

### Two-Tier Subscription Model
- **Free Tier (default)**: Access to basic recipes and limited features
- **Premium Tier (paid)**: Access to all recipes (basic + premium) and AI features

### Database Schema Changes

#### Users Table
Added subscription-related columns:
```sql
- subscription_tier: ENUM('free', 'premium') DEFAULT 'free'
- subscription_status: ENUM('active', 'expired', 'cancelled', 'trial') DEFAULT 'active'
- subscription_start_date: TIMESTAMP
- subscription_end_date: TIMESTAMP
- subscription_updated_at: TIMESTAMP
```

#### Recipes Table
Added premium flag:
```sql
- is_premium: BOOLEAN DEFAULT FALSE
```

#### New Tables
1. **subscriptions**: Stores subscription payment records for LiqPay integration
2. **subscription_events**: Audit log for subscription changes

#### Helper Functions
- `has_active_premium_subscription(user_id)`: Check if user has active premium
- `get_user_subscription_tier(user_id)`: Get user's current tier
- `log_subscription_event()`: Log subscription changes

### Migration Files
- `backend/migrations/add_premium_subscription_system.sql`: Main migration
- `backend/migrations/mark_sample_premium_recipe.sql`: Mark one random recipe as premium for testing

## Backend Components

### 1. Schemas (`backend/app/schemas/subscription.py`)

#### Enums
- `SubscriptionTier`: FREE, PREMIUM
- `SubscriptionStatus`: ACTIVE, EXPIRED, CANCELLED, TRIAL

#### Models
- `UserSubscriptionInfo`: Embedded in User model
- `SubscriptionStatusResponse`: Complete status with features
- `PremiumAccessCheck`: Access validation result
- `SubscriptionUpdateRequest`: For updating subscriptions
- `UpgradePrompt`: Upgrade messaging for different features

#### Features Mapping
```python
FREE_TIER_FEATURES = {
    "ai_recipe_generation": False,
    "ai_cooking_tips": False,
    "ai_substitutions": False,
    "ai_nutrition_analysis": False,
    "premium_recipes": False,
    "advanced_search": False,
    "basic_recipes": True,
    "basic_search": True,
    "favorites": True,
}

PREMIUM_TIER_FEATURES = {
    # All features set to True
}
```

### 2. Subscription Service (`backend/app/services/subscription_service.py`)

Core business logic for subscription management:

#### Key Methods
- `get_user_subscription(user_id)`: Retrieve user subscription info
- `get_subscription_status(user_id)`: Get complete status with features
- `check_premium_access(user_id, feature)`: Validate premium access
- `update_subscription(user_id, tier, status, end_date)`: Update subscription
- `grant_premium_access(user_id, duration_days)`: Grant premium for testing
- `revoke_premium_access(user_id)`: Downgrade to free
- `can_access_recipe(user_id, recipe_id, is_premium)`: Check recipe access

### 3. Access Control Middleware (`backend/app/core/premium_access.py`)

#### Custom Exception
```python
class PremiumAccessDenied(HTTPException):
    """Raised when user tries to access premium content without subscription"""
    status_code = 403
    # Includes upgrade_prompt for frontend display
```

#### Dependencies
- `require_premium_access()`: Protect premium endpoints
- `require_ai_access()`: Specifically for AI features
- `get_user_with_subscription()`: Attach subscription info to user
- `check_recipe_access(recipe_id, is_premium, user)`: Validate recipe access

#### Helper Functions
- `filter_recipes_by_subscription(recipes, user_id, include_premium)`: Filter recipe lists

### 4. API Endpoints

#### Recipe Endpoints (`backend/app/api/v1/endpoints/recipes.py`)
**Modified:**
- `GET /api/v1/recipes/`: Added premium filtering based on user subscription
- `GET /api/v1/recipes/{recipe_id}`: Added access control for premium recipes
- `GET /api/v1/recipes/featured`: Includes is_premium field

**Changes:**
- Added `current_user` parameter to endpoints
- Filter out premium recipes for free users
- Include `is_premium` field in all recipe responses
- Check access before returning premium recipe details

#### AI Endpoints (`backend/app/api/v1/endpoints/ai.py`)
**All AI endpoints now require premium access:**
- `POST /api/v1/ai/recipe-suggestions` (Premium Only)
- `POST /api/v1/ai/ingredient-substitutions` (Premium Only)
- `POST /api/v1/ai/cooking-tips` (Premium Only)
- `POST /api/v1/ai/nutrition-analysis` (Premium Only)
- `POST /api/v1/ai/improve-instructions` (Premium Only)

**Implementation:**
- Changed dependency from `get_current_user` to `require_ai_access`
- Returns 403 with upgrade prompt if user is not premium

#### Subscription Endpoints (`backend/app/api/v1/endpoints/subscription.py`)
New endpoints for subscription management:

1. `GET /api/v1/subscription/status`
   - Get current user's subscription status and features
   - Returns: SubscriptionStatusResponse

2. `GET /api/v1/subscription/check-access?feature=<feature_name>`
   - Check if user has premium access for specific feature
   - Returns: PremiumAccessCheck

3. `GET /api/v1/subscription/features`
   - Get list of features available to current user
   - Returns: Feature dictionary based on tier

4. `GET /api/v1/subscription/upgrade-prompts/{prompt_type}`
   - Get upgrade prompt for specific feature type
   - Types: 'ai_features', 'premium_recipes', 'advanced_search'
   - Returns: UpgradePrompt

5. `PUT /api/v1/subscription/update`
   - Update user subscription (for admin/testing)
   - Body: SubscriptionUpdateRequest
   - Returns: Updated subscription status

6. `POST /api/v1/subscription/grant-premium?duration_days=30`
   - Grant premium access for testing
   - Returns: Success message

7. `POST /api/v1/subscription/revoke-premium`
   - Revoke premium access (testing)
   - Returns: Success message

8. `GET /api/v1/subscription/tiers`
   - Get information about available subscription tiers
   - Returns: List of tiers with features and pricing

### 5. Exception Handling (`backend/app/main.py`)

Added custom exception handler for `PremiumAccessDenied`:
```python
@app.exception_handler(PremiumAccessDenied)
async def premium_access_denied_handler(request, exc):
    return JSONResponse(
        status_code=403,
        content={
            "detail": exc.detail,
            "error_code": "PREMIUM_ACCESS_REQUIRED",
            "type": "premium_access_denied",
            "upgrade_prompt": exc.upgrade_prompt.dict()  # Frontend can display this
        }
    )
```

## API Response Examples

### Successful Subscription Status
```json
{
  "user_id": "uuid",
  "subscription": {
    "tier": "premium",
    "status": "active",
    "start_date": "2025-01-01T00:00:00Z",
    "end_date": "2025-02-01T00:00:00Z",
    "is_active": true
  },
  "has_premium_access": true,
  "features": {
    "ai_recipe_generation": true,
    "ai_cooking_tips": true,
    "premium_recipes": true,
    ...
  }
}
```

### Premium Access Denied (403)
```json
{
  "detail": "This feature requires a premium subscription",
  "error_code": "PREMIUM_ACCESS_REQUIRED",
  "type": "premium_access_denied",
  "upgrade_prompt": {
    "title": "Unlock AI Recipe Generation",
    "message": "Generate personalized recipes with AI...",
    "features": ["AI Recipe Generation", "Cooking Tips", ...],
    "cta_text": "Upgrade to Premium",
    "cta_action": "navigate_to_subscription"
  }
}
```

## Testing

### Database Setup
1. Run migration: `backend/migrations/add_premium_subscription_system.sql`
2. Mark sample recipe as premium: `backend/migrations/mark_sample_premium_recipe.sql`

### Manual Testing
You can manually update user subscription in the database:
```sql
UPDATE users 
SET subscription_tier = 'premium',
    subscription_status = 'active',
    subscription_end_date = NOW() + INTERVAL '30 days'
WHERE id = 'your-user-id';
```

Or use the API endpoints:
```bash
# Grant premium access
POST /api/v1/subscription/grant-premium?duration_days=30

# Check status
GET /api/v1/subscription/status

# Revoke premium
POST /api/v1/subscription/revoke-premium
```

## Security Considerations

1. **Backend Enforcement**: All access control is enforced on the backend
2. **Token Validation**: All endpoints require valid Firebase authentication
3. **Subscription Validation**: Checks both tier AND status AND expiration date
4. **Audit Logging**: All subscription changes are logged to subscription_events table
5. **Payment Integration Ready**: Subscriptions table prepared for LiqPay webhooks

## Next Steps (Frontend Implementation)

The backend is now complete and ready for frontend integration. The frontend needs to:

1. Add `isPremium` field to Recipe model
2. Create subscription state management with Riverpod
3. Display premium badges on recipes
4. Show upgrade prompts when accessing premium features
5. Create subscription status page
6. Gate AI features in the UI
7. Handle 403 errors with upgrade prompts

## Future Enhancements

1. **Payment Integration**: Connect LiqPay webhooks to subscription endpoints
2. **Trial Periods**: Implement free trial logic
3. **Promo Codes**: Add discount/promo code support
4. **Analytics**: Track conversion rates and feature usage
5. **Admin Dashboard**: Create admin interface for subscription management

