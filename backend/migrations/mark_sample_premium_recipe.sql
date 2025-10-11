-- Mark one random recipe as premium for testing
-- This script selects one recipe and marks it as premium

DO $$
DECLARE
    selected_recipe_id UUID;
    selected_recipe_title VARCHAR;
BEGIN
    -- Select one random recipe that is public and not already premium
    SELECT id, title INTO selected_recipe_id, selected_recipe_title
    FROM recipes
    WHERE is_public = TRUE 
    AND is_premium = FALSE
    ORDER BY RANDOM()
    LIMIT 1;
    
    -- Mark it as premium
    IF selected_recipe_id IS NOT NULL THEN
        UPDATE recipes 
        SET is_premium = TRUE,
            updated_at = NOW()
        WHERE id = selected_recipe_id;
        
        RAISE NOTICE 'Marked recipe as premium:';
        RAISE NOTICE 'ID: %', selected_recipe_id;
        RAISE NOTICE 'Title: %', selected_recipe_title;
    ELSE
        RAISE NOTICE 'No recipes found to mark as premium';
    END IF;
END $$;

