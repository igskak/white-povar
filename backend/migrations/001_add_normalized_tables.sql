-- Migration 001: Add normalized tables alongside existing schema
-- This migration adds the new normalized tables without dropping existing ones
-- Allows for gradual migration and rollback if needed

-- ============================================================================
-- ADD NEW NORMALIZED TABLES
-- ============================================================================

-- Units reference table
CREATE TABLE IF NOT EXISTS units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name_en VARCHAR(50) NOT NULL UNIQUE,
    name_original VARCHAR(50),
    original_language VARCHAR(5),
    abbreviation_en VARCHAR(10) NOT NULL,
    abbreviation_original VARCHAR(10),
    unit_type VARCHAR(20) NOT NULL,
    system VARCHAR(10) NOT NULL,
    base_unit_id UUID REFERENCES units(id),
    conversion_factor DECIMAL(20,10),
    is_base_unit BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT check_unit_type CHECK (unit_type IN ('mass', 'volume', 'count', 'length', 'temperature')),
    CONSTRAINT check_system CHECK (system IN ('metric', 'imperial', 'us', 'other')),
    CONSTRAINT check_base_unit_conversion CHECK (
        (is_base_unit = TRUE AND base_unit_id IS NULL AND conversion_factor IS NULL) OR
        (is_base_unit = FALSE AND base_unit_id IS NOT NULL AND conversion_factor IS NOT NULL)
    )
);

-- Ingredient categories
CREATE TABLE IF NOT EXISTS ingredient_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name_en VARCHAR(100) NOT NULL,
    name_original VARCHAR(100),
    original_language VARCHAR(5),
    parent_id UUID REFERENCES ingredient_categories(id),
    description_en TEXT,
    icon_url TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Base ingredients (reusable definitions)
CREATE TABLE IF NOT EXISTS base_ingredients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name_en VARCHAR(200) NOT NULL,
    name_original VARCHAR(200),
    original_language VARCHAR(5) DEFAULT 'en',
    category_id UUID REFERENCES ingredient_categories(id),
    density_g_per_ml DECIMAL(8,4),
    default_unit_id UUID REFERENCES units(id),
    nutritional_data JSONB,
    aliases TEXT[],
    description_en TEXT,
    storage_tips_en TEXT,
    substitutes TEXT[],
    allergens TEXT[],
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT unique_name_en UNIQUE (name_en)
);

-- Recipe-ingredient junction table
CREATE TABLE IF NOT EXISTS recipe_ingredients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    base_ingredient_id UUID NOT NULL REFERENCES base_ingredients(id),
    amount_canonical DECIMAL(12,4) NOT NULL,
    unit_canonical_id UUID NOT NULL REFERENCES units(id),
    amount_display DECIMAL(12,4),
    unit_display_id UUID REFERENCES units(id),
    notes TEXT,
    notes_en TEXT,
    "order" INTEGER NOT NULL CHECK ("order" >= 0),
    is_optional BOOLEAN DEFAULT FALSE,
    preparation_method TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT check_positive_canonical_amount CHECK (amount_canonical > 0),
    CONSTRAINT check_positive_display_amount CHECK (amount_display IS NULL OR amount_display > 0),
    CONSTRAINT unique_recipe_ingredient_order UNIQUE (recipe_id, "order")
);

-- ============================================================================
-- ENHANCE EXISTING TABLES
-- ============================================================================

-- Add multi-language columns to recipes table
ALTER TABLE recipes 
ADD COLUMN IF NOT EXISTS title_en VARCHAR(200),
ADD COLUMN IF NOT EXISTS description_en TEXT,
ADD COLUMN IF NOT EXISTS cuisine_en VARCHAR(100),
ADD COLUMN IF NOT EXISTS category_en VARCHAR(100),
ADD COLUMN IF NOT EXISTS instructions_en TEXT[],
ADD COLUMN IF NOT EXISTS tags_en TEXT[],
ADD COLUMN IF NOT EXISTS original_language VARCHAR(5) DEFAULT 'en',
ADD COLUMN IF NOT EXISTS source_url TEXT;

-- Add multi-language columns to chefs table
ALTER TABLE chefs
ADD COLUMN IF NOT EXISTS name_en VARCHAR(100),
ADD COLUMN IF NOT EXISTS bio_en TEXT,
ADD COLUMN IF NOT EXISTS original_language VARCHAR(5) DEFAULT 'en';

-- Enhance nutrition table
ALTER TABLE nutrition
ADD COLUMN IF NOT EXISTS serving_size_g DECIMAL(8,2),
ADD COLUMN IF NOT EXISTS calories_per_serving INTEGER CHECK (calories_per_serving >= 0),
ADD COLUMN IF NOT EXISTS calories_per_100g INTEGER CHECK (calories_per_100g >= 0),
ADD COLUMN IF NOT EXISTS cholesterol_mg DECIMAL(8,2) CHECK (cholesterol_mg >= 0),
ADD COLUMN IF NOT EXISTS vitamin_data JSONB,
ADD COLUMN IF NOT EXISTS allergen_info TEXT[],
ADD COLUMN IF NOT EXISTS dietary_flags TEXT[],
ADD COLUMN IF NOT EXISTS calculation_method VARCHAR(20) DEFAULT 'estimated',
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Add preferences to users table
ALTER TABLE users
ADD COLUMN IF NOT EXISTS preferences JSONB DEFAULT '{}';

-- ============================================================================
-- POPULATE INITIAL DATA
-- ============================================================================

-- Insert base metric units (mass)
INSERT INTO units (name_en, abbreviation_en, unit_type, system, is_base_unit) VALUES
('gram', 'g', 'mass', 'metric', TRUE),
('kilogram', 'kg', 'mass', 'metric', FALSE),
('milligram', 'mg', 'mass', 'metric', FALSE)
ON CONFLICT (name_en) DO NOTHING;

-- Insert base metric units (volume)
INSERT INTO units (name_en, abbreviation_en, unit_type, system, is_base_unit) VALUES
('milliliter', 'ml', 'volume', 'metric', TRUE),
('liter', 'l', 'volume', 'metric', FALSE),
('deciliter', 'dl', 'volume', 'metric', FALSE)
ON CONFLICT (name_en) DO NOTHING;

-- Insert count units
INSERT INTO units (name_en, abbreviation_en, unit_type, system, is_base_unit) VALUES
('piece', 'pc', 'count', 'metric', TRUE),
('dozen', 'dz', 'count', 'metric', FALSE)
ON CONFLICT (name_en) DO NOTHING;

-- Insert US/Imperial volume units
INSERT INTO units (name_en, abbreviation_en, unit_type, system, is_base_unit) VALUES
('teaspoon', 'tsp', 'volume', 'us', FALSE),
('tablespoon', 'tbsp', 'volume', 'us', FALSE),
('fluid ounce', 'fl oz', 'volume', 'us', FALSE),
('cup', 'cup', 'volume', 'us', FALSE),
('pint', 'pt', 'volume', 'us', FALSE),
('quart', 'qt', 'volume', 'us', FALSE),
('gallon', 'gal', 'volume', 'us', FALSE)
ON CONFLICT (name_en) DO NOTHING;

-- Insert Imperial/US mass units
INSERT INTO units (name_en, abbreviation_en, unit_type, system, is_base_unit) VALUES
('ounce', 'oz', 'mass', 'imperial', FALSE),
('pound', 'lb', 'mass', 'imperial', FALSE)
ON CONFLICT (name_en) DO NOTHING;

-- Update conversion factors
UPDATE units SET base_unit_id = (SELECT id FROM units WHERE name_en = 'gram'), conversion_factor = 1000.0 WHERE name_en = 'kilogram';
UPDATE units SET base_unit_id = (SELECT id FROM units WHERE name_en = 'gram'), conversion_factor = 0.001 WHERE name_en = 'milligram';

UPDATE units SET base_unit_id = (SELECT id FROM units WHERE name_en = 'milliliter'), conversion_factor = 1000.0 WHERE name_en = 'liter';
UPDATE units SET base_unit_id = (SELECT id FROM units WHERE name_en = 'milliliter'), conversion_factor = 100.0 WHERE name_en = 'deciliter';

UPDATE units SET base_unit_id = (SELECT id FROM units WHERE name_en = 'piece'), conversion_factor = 12.0 WHERE name_en = 'dozen';

-- US volume conversions to milliliters
UPDATE units SET base_unit_id = (SELECT id FROM units WHERE name_en = 'milliliter'), conversion_factor = 4.92892 WHERE name_en = 'teaspoon';
UPDATE units SET base_unit_id = (SELECT id FROM units WHERE name_en = 'milliliter'), conversion_factor = 14.7868 WHERE name_en = 'tablespoon';
UPDATE units SET base_unit_id = (SELECT id FROM units WHERE name_en = 'milliliter'), conversion_factor = 29.5735 WHERE name_en = 'fluid ounce';
UPDATE units SET base_unit_id = (SELECT id FROM units WHERE name_en = 'milliliter'), conversion_factor = 236.588 WHERE name_en = 'cup';
UPDATE units SET base_unit_id = (SELECT id FROM units WHERE name_en = 'milliliter'), conversion_factor = 473.176 WHERE name_en = 'pint';
UPDATE units SET base_unit_id = (SELECT id FROM units WHERE name_en = 'milliliter'), conversion_factor = 946.353 WHERE name_en = 'quart';
UPDATE units SET base_unit_id = (SELECT id FROM units WHERE name_en = 'milliliter'), conversion_factor = 3785.41 WHERE name_en = 'gallon';

-- Imperial mass conversions to grams
UPDATE units SET base_unit_id = (SELECT id FROM units WHERE name_en = 'gram'), conversion_factor = 28.3495 WHERE name_en = 'ounce';
UPDATE units SET base_unit_id = (SELECT id FROM units WHERE name_en = 'gram'), conversion_factor = 453.592 WHERE name_en = 'pound';

-- Insert ingredient categories
INSERT INTO ingredient_categories (name_en, description_en, sort_order) VALUES
('Vegetables', 'Fresh and preserved vegetables', 1),
('Fruits', 'Fresh and dried fruits', 2),
('Proteins', 'Meat, fish, poultry, and plant proteins', 3),
('Dairy & Eggs', 'Milk products and eggs', 4),
('Grains & Cereals', 'Rice, pasta, bread, and cereals', 5),
('Herbs & Spices', 'Fresh and dried herbs and spices', 6),
('Oils & Fats', 'Cooking oils, butter, and other fats', 7),
('Condiments & Sauces', 'Sauces, vinegars, and condiments', 8),
('Nuts & Seeds', 'All types of nuts and seeds', 9),
('Beverages', 'Liquids used in cooking', 10),
('Baking', 'Flour, sugar, baking powder, etc.', 11),
('Other', 'Miscellaneous ingredients', 99)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- CREATE INDEXES
-- ============================================================================

-- Unit indexes
CREATE INDEX IF NOT EXISTS idx_units_type_system ON units(unit_type, system);
CREATE INDEX IF NOT EXISTS idx_units_base_unit ON units(base_unit_id);
CREATE INDEX IF NOT EXISTS idx_units_active ON units(is_active);

-- Ingredient indexes
CREATE INDEX IF NOT EXISTS idx_base_ingredients_name_en ON base_ingredients(name_en);
CREATE INDEX IF NOT EXISTS idx_base_ingredients_category ON base_ingredients(category_id);
CREATE INDEX IF NOT EXISTS idx_base_ingredients_active ON base_ingredients(is_active);
CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_recipe ON recipe_ingredients(recipe_id);
CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_ingredient ON recipe_ingredients(base_ingredient_id);
CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_order ON recipe_ingredients(recipe_id, "order");

-- Category indexes
CREATE INDEX IF NOT EXISTS idx_ingredient_categories_parent ON ingredient_categories(parent_id);
CREATE INDEX IF NOT EXISTS idx_ingredient_categories_active ON ingredient_categories(is_active);

-- Enhanced recipe indexes
CREATE INDEX IF NOT EXISTS idx_recipes_language ON recipes(original_language);

-- Full-text search on English content
CREATE INDEX IF NOT EXISTS idx_recipes_search_en ON recipes USING gin(
    to_tsvector('english', 
        COALESCE(title_en, title) || ' ' || 
        COALESCE(description_en, description) || ' ' ||
        COALESCE(array_to_string(tags_en, ' '), array_to_string(tags, ' '))
    )
);

CREATE INDEX IF NOT EXISTS idx_base_ingredients_search ON base_ingredients USING gin(
    to_tsvector('english', 
        name_en || ' ' || 
        COALESCE(array_to_string(aliases, ' '), '') || ' ' ||
        COALESCE(description_en, '')
    )
);

-- ============================================================================
-- ADD TRIGGERS
-- ============================================================================

-- Triggers for updated_at
CREATE TRIGGER IF NOT EXISTS update_base_ingredients_updated_at 
    BEFORE UPDATE ON base_ingredients 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER IF NOT EXISTS update_nutrition_updated_at 
    BEFORE UPDATE ON nutrition 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- POPULATE ENGLISH CANONICAL FIELDS
-- ============================================================================

-- Update existing recipes to use current content as English canonical
UPDATE recipes SET 
    title_en = title,
    description_en = description,
    cuisine_en = cuisine,
    category_en = category,
    instructions_en = instructions,
    tags_en = tags,
    original_language = 'en'
WHERE title_en IS NULL;

-- Update existing chefs to use current content as English canonical
UPDATE chefs SET
    name_en = name,
    bio_en = bio,
    original_language = 'en'
WHERE name_en IS NULL;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

-- Add migration tracking
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(50) PRIMARY KEY,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    description TEXT
);

INSERT INTO schema_migrations (version, description) VALUES
('001', 'Add normalized tables for units, ingredients, and multi-language support')
ON CONFLICT (version) DO NOTHING;
