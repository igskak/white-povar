-- Normalized White-Label Cooking App Database Schema
-- Enhanced version with proper normalization, multi-language support, and unit standardization

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- CORE TABLES (Enhanced existing tables)
-- ============================================================================

-- Chefs table (enhanced with multi-language support)
CREATE TABLE chefs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),                    -- Canonical English name
    bio TEXT NOT NULL,
    bio_en TEXT,                            -- Canonical English bio
    app_name VARCHAR(50) NOT NULL,
    avatar_url TEXT,
    logo_url TEXT,
    theme_config JSONB NOT NULL DEFAULT '{}',
    social_links JSONB DEFAULT '{}',
    original_language VARCHAR(5) DEFAULT 'en',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Users table (unchanged)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255),
    chef_id UUID REFERENCES chefs(id) ON DELETE SET NULL,
    favorites UUID[] DEFAULT '{}',
    preferences JSONB DEFAULT '{}',          -- User preferences (units, language, etc.)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enhanced recipes table with multi-language support
CREATE TABLE recipes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(200) NOT NULL,
    title_en VARCHAR(200),                   -- Canonical English title
    description TEXT NOT NULL,
    description_en TEXT,                     -- Canonical English description
    chef_id UUID NOT NULL REFERENCES chefs(id) ON DELETE CASCADE,
    cuisine VARCHAR(100) NOT NULL,
    cuisine_en VARCHAR(100),                 -- Canonical English cuisine
    category VARCHAR(100) NOT NULL,
    category_en VARCHAR(100),                -- Canonical English category
    difficulty INTEGER NOT NULL CHECK (difficulty >= 1 AND difficulty <= 5),
    prep_time_minutes INTEGER NOT NULL CHECK (prep_time_minutes >= 0),
    cook_time_minutes INTEGER NOT NULL CHECK (cook_time_minutes >= 0),
    total_time_minutes INTEGER GENERATED ALWAYS AS (prep_time_minutes + cook_time_minutes) STORED,
    servings INTEGER NOT NULL CHECK (servings >= 1),
    instructions TEXT[] NOT NULL,
    instructions_en TEXT[],                  -- Canonical English instructions
    images TEXT[] DEFAULT '{}',
    tags TEXT[] DEFAULT '{}',
    tags_en TEXT[] DEFAULT '{}',             -- Canonical English tags
    is_featured BOOLEAN DEFAULT FALSE,
    original_language VARCHAR(5) DEFAULT 'en',
    source_url TEXT,                         -- Original recipe source
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- UNITS AND MEASUREMENTS
-- ============================================================================

-- Units reference table
CREATE TABLE units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name_en VARCHAR(50) NOT NULL UNIQUE,
    name_original VARCHAR(50),
    original_language VARCHAR(5),
    abbreviation_en VARCHAR(10) NOT NULL,
    abbreviation_original VARCHAR(10),
    unit_type VARCHAR(20) NOT NULL,          -- 'mass', 'volume', 'count', 'length', 'temperature'
    system VARCHAR(10) NOT NULL,             -- 'metric', 'imperial', 'us'
    base_unit_id UUID REFERENCES units(id),  -- Reference to metric base unit
    conversion_factor DECIMAL(20,10),        -- Factor to convert to base unit
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
CREATE TABLE ingredient_categories (
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

-- ============================================================================
-- NORMALIZED INGREDIENTS
-- ============================================================================

-- Base ingredients (reusable definitions)
CREATE TABLE base_ingredients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name_en VARCHAR(200) NOT NULL,           -- Canonical English name
    name_original VARCHAR(200),              -- Original language name
    original_language VARCHAR(5) DEFAULT 'en',
    category_id UUID REFERENCES ingredient_categories(id),
    density_g_per_ml DECIMAL(8,4),          -- For volume/weight conversion (optional)
    default_unit_id UUID REFERENCES units(id),
    nutritional_data JSONB,                 -- Per 100g nutritional info
    aliases TEXT[],                         -- Alternative names for search
    description_en TEXT,                    -- Brief description
    storage_tips_en TEXT,                   -- Storage recommendations
    substitutes TEXT[],                     -- Possible substitutes (ingredient IDs)
    allergens TEXT[],                       -- Common allergens
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT unique_name_en UNIQUE (name_en)
);

-- Recipe-ingredient junction table (replaces old ingredients table)
CREATE TABLE recipe_ingredients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    base_ingredient_id UUID NOT NULL REFERENCES base_ingredients(id),
    amount_canonical DECIMAL(12,4) NOT NULL,    -- Always in metric base units (g or ml)
    unit_canonical_id UUID NOT NULL REFERENCES units(id),
    amount_display DECIMAL(12,4),              -- Original/display amount
    unit_display_id UUID REFERENCES units(id), -- Original/display unit
    notes TEXT,
    notes_en TEXT,                              -- Canonical English notes
    "order" INTEGER NOT NULL CHECK ("order" >= 0),
    is_optional BOOLEAN DEFAULT FALSE,
    preparation_method TEXT,                    -- "chopped", "diced", "minced", etc.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT check_positive_canonical_amount CHECK (amount_canonical > 0),
    CONSTRAINT check_positive_display_amount CHECK (amount_display IS NULL OR amount_display > 0),
    CONSTRAINT unique_recipe_ingredient_order UNIQUE (recipe_id, "order")
);

-- ============================================================================
-- NUTRITION AND ADDITIONAL DATA
-- ============================================================================

-- Enhanced nutrition table
CREATE TABLE nutrition (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    serving_size_g DECIMAL(8,2),
    calories_per_serving INTEGER CHECK (calories_per_serving >= 0),
    calories_per_100g INTEGER CHECK (calories_per_100g >= 0),
    protein_g DECIMAL(8,2) CHECK (protein_g >= 0),
    carbs_g DECIMAL(8,2) CHECK (carbs_g >= 0),
    fat_g DECIMAL(8,2) CHECK (fat_g >= 0),
    fiber_g DECIMAL(8,2) CHECK (fiber_g >= 0),
    sugar_g DECIMAL(8,2) CHECK (sugar_g >= 0),
    sodium_mg DECIMAL(8,2) CHECK (sodium_mg >= 0),
    cholesterol_mg DECIMAL(8,2) CHECK (cholesterol_mg >= 0),
    vitamin_data JSONB,                     -- Additional vitamin/mineral data
    allergen_info TEXT[],                   -- Recipe-level allergen information
    dietary_flags TEXT[],                   -- "vegetarian", "vegan", "gluten-free", etc.
    calculation_method VARCHAR(20) DEFAULT 'estimated', -- 'estimated', 'calculated', 'lab-tested'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Recipe indexes
CREATE INDEX idx_recipes_chef_id ON recipes(chef_id);
CREATE INDEX idx_recipes_cuisine_en ON recipes(cuisine_en);
CREATE INDEX idx_recipes_category_en ON recipes(category_en);
CREATE INDEX idx_recipes_difficulty ON recipes(difficulty);
CREATE INDEX idx_recipes_total_time ON recipes(total_time_minutes);
CREATE INDEX idx_recipes_is_featured ON recipes(is_featured);
CREATE INDEX idx_recipes_created_at ON recipes(created_at);
CREATE INDEX idx_recipes_language ON recipes(original_language);

-- Ingredient indexes
CREATE INDEX idx_base_ingredients_name_en ON base_ingredients(name_en);
CREATE INDEX idx_base_ingredients_category ON base_ingredients(category_id);
CREATE INDEX idx_base_ingredients_active ON base_ingredients(is_active);
CREATE INDEX idx_recipe_ingredients_recipe ON recipe_ingredients(recipe_id);
CREATE INDEX idx_recipe_ingredients_ingredient ON recipe_ingredients(base_ingredient_id);
CREATE INDEX idx_recipe_ingredients_order ON recipe_ingredients(recipe_id, "order");

-- Unit indexes
CREATE INDEX idx_units_type_system ON units(unit_type, system);
CREATE INDEX idx_units_base_unit ON units(base_unit_id);
CREATE INDEX idx_units_active ON units(is_active);

-- Category indexes
CREATE INDEX idx_ingredient_categories_parent ON ingredient_categories(parent_id);
CREATE INDEX idx_ingredient_categories_active ON ingredient_categories(is_active);

-- User indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_chef_id ON users(chef_id);

-- ============================================================================
-- FULL-TEXT SEARCH INDEXES
-- ============================================================================

-- Full-text search on English content
CREATE INDEX idx_recipes_search_en ON recipes USING gin(
    to_tsvector('english', 
        COALESCE(title_en, title) || ' ' || 
        COALESCE(description_en, description) || ' ' ||
        COALESCE(array_to_string(tags_en, ' '), array_to_string(tags, ' '))
    )
);

CREATE INDEX idx_base_ingredients_search ON base_ingredients USING gin(
    to_tsvector('english', 
        name_en || ' ' || 
        COALESCE(array_to_string(aliases, ' '), '') || ' ' ||
        COALESCE(description_en, '')
    )
);

-- ============================================================================
-- TRIGGERS FOR UPDATED_AT
-- ============================================================================

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_chefs_updated_at BEFORE UPDATE ON chefs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_recipes_updated_at BEFORE UPDATE ON recipes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_base_ingredients_updated_at BEFORE UPDATE ON base_ingredients FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_nutrition_updated_at BEFORE UPDATE ON nutrition FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- INITIAL DATA - UNITS
-- ============================================================================

-- Base metric units (mass)
INSERT INTO units (name_en, abbreviation_en, unit_type, system, is_base_unit) VALUES
('gram', 'g', 'mass', 'metric', TRUE),
('kilogram', 'kg', 'mass', 'metric', FALSE),
('milligram', 'mg', 'mass', 'metric', FALSE);

-- Base metric units (volume)
INSERT INTO units (name_en, abbreviation_en, unit_type, system, is_base_unit) VALUES
('milliliter', 'ml', 'volume', 'metric', TRUE),
('liter', 'l', 'volume', 'metric', FALSE),
('deciliter', 'dl', 'volume', 'metric', FALSE);

-- Count units
INSERT INTO units (name_en, abbreviation_en, unit_type, system, is_base_unit) VALUES
('piece', 'pc', 'count', 'metric', TRUE),
('dozen', 'dz', 'count', 'metric', FALSE);

-- US/Imperial volume units
INSERT INTO units (name_en, abbreviation_en, unit_type, system, is_base_unit) VALUES
('teaspoon', 'tsp', 'volume', 'us', FALSE),
('tablespoon', 'tbsp', 'volume', 'us', FALSE),
('fluid ounce', 'fl oz', 'volume', 'us', FALSE),
('cup', 'cup', 'volume', 'us', FALSE),
('pint', 'pt', 'volume', 'us', FALSE),
('quart', 'qt', 'volume', 'us', FALSE),
('gallon', 'gal', 'volume', 'us', FALSE);

-- Imperial/US mass units
INSERT INTO units (name_en, abbreviation_en, unit_type, system, is_base_unit) VALUES
('ounce', 'oz', 'mass', 'imperial', FALSE),
('pound', 'lb', 'mass', 'imperial', FALSE);

-- Now update with conversion factors and base unit references
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

-- ============================================================================
-- INITIAL DATA - INGREDIENT CATEGORIES
-- ============================================================================

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
('Other', 'Miscellaneous ingredients', 99);
