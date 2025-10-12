-- Migration: Update existing users with default subscription tier
-- Description: Sets subscription_tier and subscription_status for users who don't have them
-- Date: 2025-10-12

-- Update users who have NULL subscription_tier to 'free'
UPDATE users
SET 
    subscription_tier = 'free',
    subscription_status = 'active'
WHERE 
    subscription_tier IS NULL 
    OR subscription_status IS NULL;

-- Verify the update
DO $$
DECLARE
    updated_count INTEGER;
    total_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO updated_count FROM users WHERE subscription_tier = 'free';
    SELECT COUNT(*) INTO total_count FROM users;
    
    RAISE NOTICE 'Migration completed!';
    RAISE NOTICE 'Total users: %', total_count;
    RAISE NOTICE 'Users with free tier: %', updated_count;
END $$;

