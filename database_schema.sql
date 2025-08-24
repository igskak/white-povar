-- White Povar Database Schema
-- Clean, normalized structure for recipe management

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- CORE TABLES
-- =====================================================

-- Users table (for authentication and user management)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    firebase_uid VARCHAR(255) UNIQUE,
    display_name VARCHAR(255),
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Chefs table (content creators)
CREATE TABLE chefs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    bio TEXT,
    avatar_url TEXT,
    website_url TEXT,
    social_links JSONB DEFAULT '{}',
    is_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- INGREDIENT SYSTEM (NORMALIZED)
-- =====================================================

-- Units of measurement
CREATE TABLE units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name_en VARCHAR(50) NOT NULL UNIQUE,
    name_it VARCHAR(50),
    abbreviation_en VARCHAR(10) NOT NULL,
    abbreviation_it VARCHAR(10),
    unit_type VARCHAR(20) NOT NULL CHECK (unit_type IN ('mass', 'volume', 'count', 'length')),
    system VARCHAR(10) NOT NULL CHECK (system IN ('metric', 'imperial', 'us')),
    base_unit_id UUID REFERENCES units(id),
    conversion_factor DECIMAL(20,10) DEFAULT 1.0,
    is_base_unit BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ingredient categories
CREATE TABLE ingredient_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name_en VARCHAR(100) NOT NULL,
    name_it VARCHAR(100),
    description_en TEXT,
    description_it TEXT,
    color_hex VARCHAR(7) DEFAULT '#6B7280',
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Base ingredients (normalized ingredient master list)
CREATE TABLE base_ingredients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name_en VARCHAR(200) NOT NULL,
    name_it VARCHAR(200),
    category_id UUID REFERENCES ingredient_categories(id),
    density_g_per_ml DECIMAL(8,4), -- For volume to mass conversions
    default_unit_id UUID REFERENCES units(id),
    aliases TEXT[], -- Alternative names for matching
    nutritional_info JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(name_en),
    CONSTRAINT valid_density CHECK (density_g_per_ml > 0)
);

-- =====================================================
-- RECIPE SYSTEM
-- =====================================================

-- Recipe categories/cuisines
CREATE TABLE recipe_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name_en VARCHAR(100) NOT NULL,
    name_it VARCHAR(100),
    description_en TEXT,
    description_it TEXT,
    color_hex VARCHAR(7) DEFAULT '#6B7280',
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Main recipes table
CREATE TABLE recipes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chef_id UUID NOT NULL REFERENCES chefs(id) ON DELETE CASCADE,
    category_id UUID REFERENCES recipe_categories(id),
    
    -- Basic info
    title VARCHAR(500) NOT NULL,
    description TEXT,
    difficulty_level INTEGER CHECK (difficulty_level BETWEEN 1 AND 5),
    
    -- Timing
    prep_time_minutes INTEGER CHECK (prep_time_minutes >= 0),
    cook_time_minutes INTEGER CHECK (cook_time_minutes >= 0),
    total_time_minutes INTEGER GENERATED ALWAYS AS (COALESCE(prep_time_minutes, 0) + COALESCE(cook_time_minutes, 0)) STORED,
    
    -- Serving info
    servings INTEGER CHECK (servings > 0),
    servings_unit VARCHAR(50) DEFAULT 'portions',
    
    -- Instructions
    instructions TEXT NOT NULL,
    instructions_structured JSONB, -- For step-by-step format
    
    -- Media
    image_url TEXT,
    video_url TEXT,
    
    -- Metadata
    source_url TEXT,
    tags TEXT[] DEFAULT '{}',
    is_public BOOLEAN DEFAULT TRUE,
    is_featured BOOLEAN DEFAULT FALSE,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT valid_title CHECK (LENGTH(TRIM(title)) > 0)
);

-- Recipe ingredients (junction table with quantities)
CREATE TABLE recipe_ingredients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    base_ingredient_id UUID REFERENCES base_ingredients(id),
    
    -- Quantity info
    amount DECIMAL(10,3) CHECK (amount > 0),
    unit_id UUID REFERENCES units(id),
    
    -- Display info (for cases where base ingredient doesn't exist yet)
    display_name VARCHAR(200) NOT NULL,
    preparation_notes VARCHAR(200), -- "diced", "chopped", "to taste", etc.
    
    -- Ordering
    sort_order INTEGER DEFAULT 0,
    
    -- Optional grouping (for complex recipes)
    ingredient_group VARCHAR(100), -- "For the sauce", "For garnish", etc.
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT valid_display_name CHECK (LENGTH(TRIM(display_name)) > 0)
);

-- =====================================================
-- NUTRITION SYSTEM
-- =====================================================

-- Nutrition information per recipe
CREATE TABLE recipe_nutrition (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    
    -- Per serving values
    calories_per_serving DECIMAL(8,2),
    protein_g_per_serving DECIMAL(8,2),
    carbs_g_per_serving DECIMAL(8,2),
    fat_g_per_serving DECIMAL(8,2),
    fiber_g_per_serving DECIMAL(8,2),
    sugar_g_per_serving DECIMAL(8,2),
    sodium_mg_per_serving DECIMAL(8,2),
    
    -- Metadata
    is_estimated BOOLEAN DEFAULT TRUE,
    calculation_method VARCHAR(50) DEFAULT 'estimated',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(recipe_id)
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Recipe search indexes
CREATE INDEX idx_recipes_chef_id ON recipes(chef_id);
CREATE INDEX idx_recipes_category_id ON recipes(category_id);
CREATE INDEX idx_recipes_is_public ON recipes(is_public);
CREATE INDEX idx_recipes_is_featured ON recipes(is_featured);
CREATE INDEX idx_recipes_created_at ON recipes(created_at DESC);
CREATE INDEX idx_recipes_title_search ON recipes USING gin(to_tsvector('english', title));
CREATE INDEX idx_recipes_tags ON recipes USING gin(tags);

-- Ingredient indexes
CREATE INDEX idx_recipe_ingredients_recipe_id ON recipe_ingredients(recipe_id);
CREATE INDEX idx_recipe_ingredients_base_ingredient_id ON recipe_ingredients(base_ingredient_id);
CREATE INDEX idx_recipe_ingredients_sort_order ON recipe_ingredients(recipe_id, sort_order);

-- Base ingredient search
CREATE INDEX idx_base_ingredients_name_search ON base_ingredients USING gin(to_tsvector('english', name_en));
CREATE INDEX idx_base_ingredients_category_id ON base_ingredients(category_id);

-- =====================================================
-- TRIGGERS FOR UPDATED_AT
-- =====================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_chefs_updated_at BEFORE UPDATE ON chefs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_base_ingredients_updated_at BEFORE UPDATE ON base_ingredients FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_recipes_updated_at BEFORE UPDATE ON recipes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_recipe_nutrition_updated_at BEFORE UPDATE ON recipe_nutrition FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
