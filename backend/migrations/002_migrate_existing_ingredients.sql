-- Migration 002: Migrate existing ingredients to normalized schema
-- This script transforms data from the old ingredients table to the new normalized structure

-- ============================================================================
-- HELPER FUNCTIONS FOR DATA MIGRATION
-- ============================================================================

-- Function to normalize ingredient names
CREATE OR REPLACE FUNCTION normalize_ingredient_name(input_name TEXT)
RETURNS TEXT AS $$
DECLARE
    normalized_name TEXT;
BEGIN
    -- Basic normalization
    normalized_name := TRIM(input_name);
    normalized_name := INITCAP(normalized_name);
    
    -- Remove common preparation terms
    normalized_name := REGEXP_REPLACE(normalized_name, '\b(Fresh|Dried|Frozen|Canned|Cooked|Raw)\b', '', 'gi');
    normalized_name := REGEXP_REPLACE(normalized_name, '\b(Large|Medium|Small|Extra Large)\b', '', 'gi');
    normalized_name := REGEXP_REPLACE(normalized_name, '\b(Chopped|Diced|Minced|Sliced|Grated|Shredded)\b', '', 'gi');
    normalized_name := REGEXP_REPLACE(normalized_name, '\b(Organic|Free-Range|Grass-Fed)\b', '', 'gi');
    
    -- Clean up extra spaces
    normalized_name := REGEXP_REPLACE(normalized_name, '\s+', ' ', 'g');
    normalized_name := TRIM(normalized_name);
    
    RETURN normalized_name;
END;
$$ LANGUAGE plpgsql;

-- Function to normalize unit names
CREATE OR REPLACE FUNCTION normalize_unit_name(input_unit TEXT)
RETURNS TEXT AS $$
DECLARE
    normalized_unit TEXT;
    unit_mapping RECORD;
BEGIN
    normalized_unit := LOWER(TRIM(input_unit));
    
    -- Remove periods and extra spaces
    normalized_unit := REPLACE(normalized_unit, '.', '');
    normalized_unit := REGEXP_REPLACE(normalized_unit, '\s+', ' ', 'g');
    normalized_unit := TRIM(normalized_unit);
    
    -- Unit mappings
    FOR unit_mapping IN 
        SELECT * FROM (VALUES
            ('g', 'gram'), ('gr', 'gram'), ('grams', 'gram'),
            ('kg', 'kilogram'), ('kilo', 'kilogram'), ('kilos', 'kilogram'),
            ('ml', 'milliliter'), ('milliliters', 'milliliter'),
            ('l', 'liter'), ('liters', 'liter'), ('litre', 'liter'), ('litres', 'liter'),
            ('dl', 'deciliter'), ('deciliters', 'deciliter'),
            ('tsp', 'teaspoon'), ('t', 'teaspoon'), ('teaspoons', 'teaspoon'),
            ('tbsp', 'tablespoon'), ('T', 'tablespoon'), ('tablespoons', 'tablespoon'),
            ('cup', 'cup'), ('cups', 'cup'), ('c', 'cup'),
            ('fl oz', 'fluid ounce'), ('fl oz', 'fluid ounce'), ('fluid ounces', 'fluid ounce'),
            ('oz', 'ounce'), ('ounces', 'ounce'),
            ('lb', 'pound'), ('lbs', 'pound'), ('pounds', 'pound'),
            ('pc', 'piece'), ('pieces', 'piece'), ('pcs', 'piece'),
            ('each', 'piece'), ('item', 'piece'), ('items', 'piece'),
            ('dozen', 'dozen'), ('dz', 'dozen'),
            ('q.b.', 'piece'), ('to taste', 'piece'), ('as needed', 'piece'),
            ('pinch', 'piece'), ('dash', 'piece'), ('splash', 'piece')
        ) AS mapping(input, output)
    LOOP
        IF normalized_unit = unit_mapping.input THEN
            RETURN unit_mapping.output;
        END IF;
    END LOOP;
    
    -- Try without 's' (plural)
    IF normalized_unit LIKE '%s' AND LENGTH(normalized_unit) > 1 THEN
        RETURN normalize_unit_name(LEFT(normalized_unit, LENGTH(normalized_unit) - 1));
    END IF;
    
    -- Return original if no mapping found
    RETURN normalized_unit;
END;
$$ LANGUAGE plpgsql;

-- Function to convert amounts to canonical units
CREATE OR REPLACE FUNCTION convert_to_canonical_amount(
    amount DECIMAL,
    unit_name TEXT,
    OUT canonical_amount DECIMAL,
    OUT canonical_unit_id UUID
)
AS $$
DECLARE
    unit_record RECORD;
    base_unit_record RECORD;
BEGIN
    -- Get unit information
    SELECT * INTO unit_record FROM units WHERE name_en = unit_name LIMIT 1;
    
    IF NOT FOUND THEN
        -- Default to piece if unit not found
        SELECT * INTO unit_record FROM units WHERE name_en = 'piece' LIMIT 1;
        canonical_amount := amount;
        canonical_unit_id := unit_record.id;
        RETURN;
    END IF;
    
    IF unit_record.is_base_unit THEN
        canonical_amount := amount;
        canonical_unit_id := unit_record.id;
    ELSE
        -- Convert to base unit
        SELECT * INTO base_unit_record FROM units WHERE id = unit_record.base_unit_id;
        canonical_amount := amount * unit_record.conversion_factor;
        canonical_unit_id := base_unit_record.id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- MIGRATE EXISTING INGREDIENTS TO BASE_INGREDIENTS
-- ============================================================================

-- Create base ingredients from unique ingredient names
INSERT INTO base_ingredients (name_en, original_language, category_id, is_active)
SELECT DISTINCT
    normalize_ingredient_name(i.name) as name_en,
    'en' as original_language,
    (SELECT id FROM ingredient_categories WHERE name_en = 'Other' LIMIT 1) as category_id,
    true as is_active
FROM ingredients i
WHERE normalize_ingredient_name(i.name) != ''
ON CONFLICT (name_en) DO NOTHING;

-- ============================================================================
-- MIGRATE EXISTING INGREDIENTS TO RECIPE_INGREDIENTS
-- ============================================================================

-- Migrate existing ingredients to the new junction table
INSERT INTO recipe_ingredients (
    recipe_id,
    base_ingredient_id,
    amount_canonical,
    unit_canonical_id,
    amount_display,
    unit_display_id,
    notes,
    "order",
    is_optional,
    created_at
)
SELECT 
    i.recipe_id,
    bi.id as base_ingredient_id,
    canonical_conversion.canonical_amount,
    canonical_conversion.canonical_unit_id,
    i.amount as amount_display,
    u_display.id as unit_display_id,
    i.notes,
    i."order",
    false as is_optional,
    i.created_at
FROM ingredients i
JOIN base_ingredients bi ON bi.name_en = normalize_ingredient_name(i.name)
LEFT JOIN units u_display ON u_display.name_en = normalize_unit_name(i.unit)
CROSS JOIN LATERAL convert_to_canonical_amount(i.amount, normalize_unit_name(i.unit)) as canonical_conversion
WHERE normalize_ingredient_name(i.name) != '';

-- ============================================================================
-- DATA QUALITY IMPROVEMENTS
-- ============================================================================

-- Update ingredient categories based on common ingredient names
UPDATE base_ingredients SET category_id = (
    SELECT id FROM ingredient_categories WHERE name_en = 'Vegetables' LIMIT 1
) WHERE name_en ILIKE ANY(ARRAY[
    '%tomato%', '%onion%', '%garlic%', '%pepper%', '%carrot%', '%celery%',
    '%potato%', '%zucchini%', '%eggplant%', '%spinach%', '%lettuce%',
    '%broccoli%', '%cauliflower%', '%cabbage%', '%cucumber%', '%radish%'
]);

UPDATE base_ingredients SET category_id = (
    SELECT id FROM ingredient_categories WHERE name_en = 'Herbs & Spices' LIMIT 1
) WHERE name_en ILIKE ANY(ARRAY[
    '%basil%', '%oregano%', '%thyme%', '%rosemary%', '%parsley%', '%cilantro%',
    '%sage%', '%mint%', '%dill%', '%chives%', '%salt%', '%pepper%',
    '%paprika%', '%cumin%', '%coriander%', '%cinnamon%', '%nutmeg%'
]);

UPDATE base_ingredients SET category_id = (
    SELECT id FROM ingredient_categories WHERE name_en = 'Oils & Fats' LIMIT 1
) WHERE name_en ILIKE ANY(ARRAY[
    '%oil%', '%butter%', '%margarine%', '%lard%', '%shortening%'
]);

UPDATE base_ingredients SET category_id = (
    SELECT id FROM ingredient_categories WHERE name_en = 'Dairy & Eggs' LIMIT 1
) WHERE name_en ILIKE ANY(ARRAY[
    '%milk%', '%cream%', '%cheese%', '%yogurt%', '%egg%', '%butter%'
]);

UPDATE base_ingredients SET category_id = (
    SELECT id FROM ingredient_categories WHERE name_en = 'Proteins' LIMIT 1
) WHERE name_en ILIKE ANY(ARRAY[
    '%chicken%', '%beef%', '%pork%', '%fish%', '%salmon%', '%tuna%',
    '%turkey%', '%lamb%', '%duck%', '%bacon%', '%ham%', '%sausage%'
]);

UPDATE base_ingredients SET category_id = (
    SELECT id FROM ingredient_categories WHERE name_en = 'Grains & Cereals' LIMIT 1
) WHERE name_en ILIKE ANY(ARRAY[
    '%pasta%', '%rice%', '%bread%', '%flour%', '%oats%', '%quinoa%',
    '%barley%', '%wheat%', '%noodle%', '%spaghetti%', '%macaroni%'
]);

-- Add common ingredient densities for volume/mass conversion
UPDATE base_ingredients SET density_g_per_ml = 1.0 WHERE name_en ILIKE '%water%';
UPDATE base_ingredients SET density_g_per_ml = 1.03 WHERE name_en ILIKE '%milk%';
UPDATE base_ingredients SET density_g_per_ml = 0.92 WHERE name_en ILIKE '%oil%';
UPDATE base_ingredients SET density_g_per_ml = 1.4 WHERE name_en ILIKE '%honey%';
UPDATE base_ingredients SET density_g_per_ml = 0.845 WHERE name_en ILIKE '%sugar%';
UPDATE base_ingredients SET density_g_per_ml = 0.593 WHERE name_en ILIKE '%flour%';
UPDATE base_ingredients SET density_g_per_ml = 2.16 WHERE name_en ILIKE '%salt%';

-- Set default units for ingredients
UPDATE base_ingredients SET default_unit_id = (
    SELECT id FROM units WHERE name_en = 'gram' LIMIT 1
) WHERE category_id IN (
    SELECT id FROM ingredient_categories WHERE name_en IN ('Herbs & Spices', 'Proteins')
);

UPDATE base_ingredients SET default_unit_id = (
    SELECT id FROM units WHERE name_en = 'milliliter' LIMIT 1
) WHERE category_id IN (
    SELECT id FROM ingredient_categories WHERE name_en IN ('Oils & Fats', 'Beverages')
);

UPDATE base_ingredients SET default_unit_id = (
    SELECT id FROM units WHERE name_en = 'piece' LIMIT 1
) WHERE category_id IN (
    SELECT id FROM ingredient_categories WHERE name_en IN ('Vegetables', 'Fruits')
) AND name_en NOT ILIKE '%powder%' AND name_en NOT ILIKE '%juice%';

-- ============================================================================
-- VALIDATION AND CLEANUP
-- ============================================================================

-- Create a report of migration results
CREATE TEMP TABLE migration_report AS
SELECT 
    'Original ingredients' as metric,
    COUNT(*) as count
FROM ingredients
UNION ALL
SELECT 
    'Unique base ingredients created' as metric,
    COUNT(*) as count
FROM base_ingredients
UNION ALL
SELECT 
    'Recipe ingredients migrated' as metric,
    COUNT(*) as count
FROM recipe_ingredients
UNION ALL
SELECT 
    'Ingredients with unknown units' as metric,
    COUNT(*) as count
FROM recipe_ingredients ri
LEFT JOIN units u ON u.id = ri.unit_display_id
WHERE u.id IS NULL;

-- Log migration results
DO $$
DECLARE
    report_row RECORD;
BEGIN
    RAISE NOTICE 'Migration 002 Results:';
    FOR report_row IN SELECT * FROM migration_report LOOP
        RAISE NOTICE '  %: %', report_row.metric, report_row.count;
    END LOOP;
END $$;

-- ============================================================================
-- CLEANUP HELPER FUNCTIONS
-- ============================================================================

-- Drop helper functions
DROP FUNCTION IF EXISTS normalize_ingredient_name(TEXT);
DROP FUNCTION IF EXISTS normalize_unit_name(TEXT);
DROP FUNCTION IF EXISTS convert_to_canonical_amount(DECIMAL, TEXT);

-- Record migration completion
INSERT INTO schema_migrations (version, description) VALUES 
('002', 'Migrate existing ingredients to normalized schema')
ON CONFLICT (version) DO NOTHING;
