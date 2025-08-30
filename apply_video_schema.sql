-- Video Feature Database Migration
-- This script adds video support to the recipes system

-- Add video fields to recipes table
ALTER TABLE recipes 
ADD COLUMN IF NOT EXISTS video_file_path TEXT;

-- Create recipe_videos table for uploaded video files
CREATE TABLE IF NOT EXISTS recipe_videos (
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

-- Create indexes for recipe_videos table
CREATE INDEX IF NOT EXISTS idx_recipe_videos_recipe_id ON recipe_videos(recipe_id);
CREATE INDEX IF NOT EXISTS idx_recipe_videos_uploaded_at ON recipe_videos(uploaded_at);
CREATE INDEX IF NOT EXISTS idx_recipe_videos_is_active ON recipe_videos(is_active);

-- Create storage bucket policy for recipe-videos (if using Supabase)
-- Note: This needs to be run in Supabase dashboard or via API
-- INSERT INTO storage.buckets (id, name, public) VALUES ('recipe-videos', 'recipe-videos', true);

-- Create RLS policies for recipe_videos table
ALTER TABLE recipe_videos ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view active videos for any recipe
CREATE POLICY IF NOT EXISTS "Users can view active recipe videos" ON recipe_videos
    FOR SELECT USING (is_active = true);

-- Policy: Authenticated users can insert videos for their own recipes
CREATE POLICY IF NOT EXISTS "Users can upload videos to their recipes" ON recipe_videos
    FOR INSERT WITH CHECK (
        auth.uid() IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM recipes 
            WHERE recipes.id = recipe_videos.recipe_id 
            AND recipes.chef_id = auth.uid()
        )
    );

-- Policy: Users can update their own videos
CREATE POLICY IF NOT EXISTS "Users can update their own videos" ON recipe_videos
    FOR UPDATE USING (uploaded_by = auth.uid());

-- Policy: Users can delete their own videos (soft delete)
CREATE POLICY IF NOT EXISTS "Users can delete their own videos" ON recipe_videos
    FOR UPDATE USING (uploaded_by = auth.uid());

COMMIT;
