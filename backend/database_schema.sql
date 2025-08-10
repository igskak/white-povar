-- White-Label Cooking App Database Schema
-- Run this in your Supabase SQL editor to create the tables

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Chefs table (white-label configurations)
CREATE TABLE chefs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    bio TEXT NOT NULL,
    app_name VARCHAR(50) NOT NULL,
    avatar_url TEXT,
    logo_url TEXT,
    theme_config JSONB NOT NULL DEFAULT '{}',
    social_links JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255),
    chef_id UUID REFERENCES chefs(id) ON DELETE SET NULL,
    favorites UUID[] DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Recipes table
CREATE TABLE recipes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    chef_id UUID NOT NULL REFERENCES chefs(id) ON DELETE CASCADE,
    cuisine VARCHAR(100) NOT NULL,
    category VARCHAR(100) NOT NULL,
    difficulty INTEGER NOT NULL CHECK (difficulty >= 1 AND difficulty <= 5),
    prep_time_minutes INTEGER NOT NULL CHECK (prep_time_minutes >= 0),
    cook_time_minutes INTEGER NOT NULL CHECK (cook_time_minutes >= 0),
    total_time_minutes INTEGER GENERATED ALWAYS AS (prep_time_minutes + cook_time_minutes) STORED,
    servings INTEGER NOT NULL CHECK (servings >= 1),
    instructions TEXT[] NOT NULL,
    images TEXT[] DEFAULT '{}',
    tags TEXT[] DEFAULT '{}',
    is_featured BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ingredients table
CREATE TABLE ingredients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    unit VARCHAR(50) NOT NULL,
    notes TEXT,
    "order" INTEGER NOT NULL CHECK ("order" >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Nutrition table (optional)
CREATE TABLE nutrition (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    calories INTEGER CHECK (calories >= 0),
    protein_g DECIMAL(8,2) CHECK (protein_g >= 0),
    carbs_g DECIMAL(8,2) CHECK (carbs_g >= 0),
    fat_g DECIMAL(8,2) CHECK (fat_g >= 0),
    fiber_g DECIMAL(8,2) CHECK (fiber_g >= 0),
    sugar_g DECIMAL(8,2) CHECK (sugar_g >= 0),
    sodium_mg DECIMAL(8,2) CHECK (sodium_mg >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_recipes_chef_id ON recipes(chef_id);
CREATE INDEX idx_recipes_cuisine ON recipes(cuisine);
CREATE INDEX idx_recipes_category ON recipes(category);
CREATE INDEX idx_recipes_difficulty ON recipes(difficulty);
CREATE INDEX idx_recipes_total_time ON recipes(total_time_minutes);
CREATE INDEX idx_recipes_is_featured ON recipes(is_featured);
CREATE INDEX idx_recipes_created_at ON recipes(created_at);
CREATE INDEX idx_ingredients_recipe_id ON ingredients(recipe_id);
CREATE INDEX idx_ingredients_order ON ingredients(recipe_id, "order");
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_chef_id ON users(chef_id);

-- Full-text search index for recipes
CREATE INDEX idx_recipes_search ON recipes USING gin(to_tsvector('english', title || ' ' || description));

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

-- Row Level Security (RLS) policies
ALTER TABLE chefs ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE nutrition ENABLE ROW LEVEL SECURITY;

-- Policies for public read access to recipes and chefs
CREATE POLICY "Public recipes are viewable by everyone" ON recipes FOR SELECT USING (true);
CREATE POLICY "Public chefs are viewable by everyone" ON chefs FOR SELECT USING (true);
CREATE POLICY "Public ingredients are viewable by everyone" ON ingredients FOR SELECT USING (true);
CREATE POLICY "Public nutrition is viewable by everyone" ON nutrition FOR SELECT USING (true);

-- Policies for authenticated users
CREATE POLICY "Users can view their own data" ON users FOR SELECT USING (auth.uid()::text = id::text);
CREATE POLICY "Users can update their own data" ON users FOR UPDATE USING (auth.uid()::text = id::text);
