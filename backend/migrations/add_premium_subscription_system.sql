-- Migration: Add Premium Subscription System
-- Description: Adds subscription tiers, premium content flags, and subscription management tables
-- Date: 2025-10-11

-- =====================================================
-- 1. ADD SUBSCRIPTION FIELDS TO USERS TABLE
-- =====================================================

-- Add subscription tier enum type
DO $$ BEGIN
    CREATE TYPE subscription_tier AS ENUM ('free', 'premium');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Add subscription status enum type
DO $$ BEGIN
    CREATE TYPE subscription_status AS ENUM ('active', 'expired', 'cancelled', 'trial');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Add subscription columns to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS subscription_tier subscription_tier DEFAULT 'free' NOT NULL,
ADD COLUMN IF NOT EXISTS subscription_status subscription_status DEFAULT 'active',
ADD COLUMN IF NOT EXISTS subscription_start_date TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS subscription_end_date TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS subscription_updated_at TIMESTAMP WITH TIME ZONE;

-- Create index for subscription queries
CREATE INDEX IF NOT EXISTS idx_users_subscription_tier ON users(subscription_tier);
CREATE INDEX IF NOT EXISTS idx_users_subscription_status ON users(subscription_status);

-- =====================================================
-- 2. ADD PREMIUM FLAG TO RECIPES TABLE
-- =====================================================

-- Add is_premium column to recipes table
ALTER TABLE recipes 
ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT FALSE NOT NULL;

-- Create index for premium recipe queries
CREATE INDEX IF NOT EXISTS idx_recipes_is_premium ON recipes(is_premium);
CREATE INDEX IF NOT EXISTS idx_recipes_premium_featured ON recipes(is_premium, is_featured) WHERE is_public = TRUE;

-- =====================================================
-- 3. CREATE SUBSCRIPTIONS TABLE FOR FUTURE PAYMENT INTEGRATION
-- =====================================================

-- Subscriptions table to track subscription history and payment details
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Subscription details
    tier subscription_tier NOT NULL,
    status subscription_status NOT NULL DEFAULT 'active',
    
    -- Billing period
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Payment information (for future LiqPay integration)
    payment_provider VARCHAR(50), -- 'liqpay', 'manual', etc.
    payment_id VARCHAR(255), -- External payment ID from provider
    payment_amount DECIMAL(10,2),
    payment_currency VARCHAR(3) DEFAULT 'UAH',
    
    -- Metadata
    auto_renew BOOLEAN DEFAULT TRUE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    cancellation_reason TEXT,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT valid_dates CHECK (end_date > start_date),
    CONSTRAINT valid_amount CHECK (payment_amount IS NULL OR payment_amount > 0)
);

-- Indexes for subscriptions table
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_end_date ON subscriptions(end_date);
CREATE INDEX IF NOT EXISTS idx_subscriptions_payment_id ON subscriptions(payment_id);

-- Trigger for subscriptions updated_at
DROP TRIGGER IF EXISTS update_subscriptions_updated_at ON subscriptions;
CREATE TRIGGER update_subscriptions_updated_at
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 4. CREATE SUBSCRIPTION EVENTS TABLE FOR AUDIT LOG
-- =====================================================

-- Subscription events for tracking changes and debugging
CREATE TABLE IF NOT EXISTS subscription_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
    
    -- Event details
    event_type VARCHAR(50) NOT NULL, -- 'created', 'renewed', 'cancelled', 'expired', 'upgraded', 'downgraded'
    old_tier subscription_tier,
    new_tier subscription_tier,
    old_status subscription_status,
    new_status subscription_status,
    
    -- Context
    triggered_by VARCHAR(50), -- 'user', 'system', 'payment_webhook', 'admin'
    metadata JSONB DEFAULT '{}',
    
    -- Timestamp
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for subscription events
CREATE INDEX IF NOT EXISTS idx_subscription_events_user_id ON subscription_events(user_id);
CREATE INDEX IF NOT EXISTS idx_subscription_events_subscription_id ON subscription_events(subscription_id);
CREATE INDEX IF NOT EXISTS idx_subscription_events_type ON subscription_events(event_type);
CREATE INDEX IF NOT EXISTS idx_subscription_events_created_at ON subscription_events(created_at);

-- =====================================================
-- 5. UPDATE EXISTING DATA
-- =====================================================

-- Set all existing users to free tier (as per requirements)
UPDATE users 
SET 
    subscription_tier = 'free',
    subscription_status = 'active',
    subscription_updated_at = NOW()
WHERE subscription_tier IS NULL;

-- Set all existing recipes to free (non-premium)
UPDATE recipes 
SET is_premium = FALSE 
WHERE is_premium IS NULL;

-- =====================================================
-- 6. HELPER FUNCTIONS
-- =====================================================

-- Function to check if user has active premium subscription
CREATE OR REPLACE FUNCTION has_active_premium_subscription(user_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM users 
        WHERE id = user_uuid 
        AND subscription_tier = 'premium' 
        AND subscription_status = 'active'
        AND (subscription_end_date IS NULL OR subscription_end_date > NOW())
    );
END;
$$ LANGUAGE plpgsql;

-- Function to get user subscription tier
CREATE OR REPLACE FUNCTION get_user_subscription_tier(user_uuid UUID)
RETURNS subscription_tier AS $$
DECLARE
    tier subscription_tier;
BEGIN
    SELECT subscription_tier INTO tier
    FROM users 
    WHERE id = user_uuid;
    
    RETURN COALESCE(tier, 'free');
END;
$$ LANGUAGE plpgsql;

-- Function to log subscription event
CREATE OR REPLACE FUNCTION log_subscription_event(
    p_user_id UUID,
    p_subscription_id UUID,
    p_event_type VARCHAR,
    p_old_tier subscription_tier,
    p_new_tier subscription_tier,
    p_old_status subscription_status,
    p_new_status subscription_status,
    p_triggered_by VARCHAR,
    p_metadata JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    event_id UUID;
BEGIN
    INSERT INTO subscription_events (
        user_id, subscription_id, event_type, 
        old_tier, new_tier, old_status, new_status,
        triggered_by, metadata
    ) VALUES (
        p_user_id, p_subscription_id, p_event_type,
        p_old_tier, p_new_tier, p_old_status, p_new_status,
        p_triggered_by, p_metadata
    ) RETURNING id INTO event_id;
    
    RETURN event_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 7. COMMENTS FOR DOCUMENTATION
-- =====================================================

COMMENT ON COLUMN users.subscription_tier IS 'User subscription tier: free or premium';
COMMENT ON COLUMN users.subscription_status IS 'Current subscription status: active, expired, cancelled, or trial';
COMMENT ON COLUMN users.subscription_start_date IS 'When the current subscription period started';
COMMENT ON COLUMN users.subscription_end_date IS 'When the current subscription period ends (NULL for lifetime/indefinite)';
COMMENT ON COLUMN recipes.is_premium IS 'Whether this recipe requires premium subscription to access';
COMMENT ON TABLE subscriptions IS 'Subscription history and payment tracking for future LiqPay integration';
COMMENT ON TABLE subscription_events IS 'Audit log of all subscription-related events';

-- =====================================================
-- 8. GRANT PERMISSIONS (if using RLS)
-- =====================================================

-- Note: Adjust these based on your Supabase RLS policies
-- These are examples and may need to be customized

-- Allow users to read their own subscription status
-- ALTER TABLE users ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY users_read_own_subscription ON users FOR SELECT USING (auth.uid() = id);

-- Allow users to read their own subscription history
-- ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY subscriptions_read_own ON subscriptions FOR SELECT USING (auth.uid() = user_id);

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================

-- Verify migration
DO $$
DECLARE
    user_count INTEGER;
    recipe_count INTEGER;
    premium_recipe_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM users WHERE subscription_tier = 'free';
    SELECT COUNT(*) INTO recipe_count FROM recipes;
    SELECT COUNT(*) INTO premium_recipe_count FROM recipes WHERE is_premium = TRUE;
    
    RAISE NOTICE 'Migration completed successfully!';
    RAISE NOTICE 'Users with free tier: %', user_count;
    RAISE NOTICE 'Total recipes: %', recipe_count;
    RAISE NOTICE 'Premium recipes: %', premium_recipe_count;
END $$;

