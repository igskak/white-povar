-- White Povar Database Schema
-- Clean, normalized structure for recipe management

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Ingestion system tables
-- Table to track recipe ingestion jobs and their status
CREATE TABLE ingestion_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_path TEXT NOT NULL,
    original_filename TEXT,
    file_size_bytes BIGINT,
    mime_type TEXT,
    status TEXT NOT NULL CHECK (status IN ('PENDING', 'PROCESSING', 'NEEDS_REVIEW', 'COMPLETED', 'FAILED', 'DLQ', 'COMPLETED_DUPLICATE')),
    error_message TEXT,
    retries INTEGER DEFAULT 0,
    confidence_score NUMERIC(3,2), -- 0.00 to 1.00
    recipe_id UUID REFERENCES recipes(id),
    duplicate_of_recipe_id UUID REFERENCES recipes(id),
    meta JSONB, -- stores detected_lang, token_usage, costs, etc.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    reviewer_notes TEXT
);

-- Table for recipe fingerprinting to detect duplicates
CREATE TABLE recipe_fingerprints (
    recipe_id UUID PRIMARY KEY REFERENCES recipes(id) ON DELETE CASCADE,
    title_normalized TEXT NOT NULL,
    cuisine_normalized TEXT,
    total_time_minutes INTEGER,
    fingerprint_hash TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table for manual review decisions (optional but useful for audit)
CREATE TABLE ingestion_reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID NOT NULL REFERENCES ingestion_jobs(id) ON DELETE CASCADE,
    reviewer_id UUID, -- could reference users/admins table if you have one
    decision TEXT NOT NULL CHECK (decision IN ('APPROVED', 'REJECTED', 'NEEDS_REVISION')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_ingestion_jobs_status ON ingestion_jobs(status);
CREATE INDEX idx_ingestion_jobs_created_at ON ingestion_jobs(created_at);
CREATE INDEX idx_recipe_fingerprints_hash ON recipe_fingerprints(fingerprint_hash);
CREATE INDEX idx_recipe_fingerprints_normalized ON recipe_fingerprints(title_normalized, cuisine_normalized);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for ingestion_jobs updated_at
CREATE TRIGGER update_ingestion_jobs_updated_at
    BEFORE UPDATE ON ingestion_jobs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

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
    video_file_path TEXT, -- For uploaded video files stored in Supabase storage
    
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

-- Recipe videos table for uploaded video files
CREATE TABLE recipe_videos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,

    -- File info
    filename VARCHAR(255) NOT NULL,
    file_path TEXT NOT NULL, -- Path in Supabase storage
    file_size BIGINT NOT NULL, -- Size in bytes
    mime_type VARCHAR(100) NOT NULL,

    -- Video metadata
    duration_seconds INTEGER, -- Video duration if available
    width INTEGER, -- Video width if available
    height INTEGER, -- Video height if available

    -- Upload info
    uploaded_by UUID, -- User who uploaded (optional)
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Status
    is_active BOOLEAN DEFAULT TRUE,

    CONSTRAINT valid_file_size CHECK (file_size > 0),
    CONSTRAINT valid_duration CHECK (duration_seconds IS NULL OR duration_seconds > 0)
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

-- Video indexes
CREATE INDEX idx_recipe_videos_recipe_id ON recipe_videos(recipe_id);
CREATE INDEX idx_recipe_videos_uploaded_at ON recipe_videos(uploaded_at);
CREATE INDEX idx_recipe_videos_is_active ON recipe_videos(is_active);

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
