-- Create storage bucket for recipe videos
INSERT INTO storage.buckets (id, name, public) 
VALUES ('recipe-videos', 'recipe-videos', true)
ON CONFLICT (id) DO NOTHING;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Allow public uploads to recipe-videos bucket" ON storage.objects;
DROP POLICY IF EXISTS "Allow public access to recipe-videos bucket" ON storage.objects;
DROP POLICY IF EXISTS "Allow public updates to recipe-videos bucket" ON storage.objects;
DROP POLICY IF EXISTS "Allow public deletes from recipe-videos bucket" ON storage.objects;

-- Create storage policy to allow public uploads
CREATE POLICY "Allow public uploads to recipe-videos bucket" ON storage.objects
FOR INSERT WITH CHECK (bucket_id = 'recipe-videos');

-- Create storage policy to allow public access to recipe-videos
CREATE POLICY "Allow public access to recipe-videos bucket" ON storage.objects
FOR SELECT USING (bucket_id = 'recipe-videos');

-- Create storage policy to allow public updates to recipe-videos
CREATE POLICY "Allow public updates to recipe-videos bucket" ON storage.objects
FOR UPDATE USING (bucket_id = 'recipe-videos');

-- Create storage policy to allow public deletes from recipe-videos
CREATE POLICY "Allow public deletes from recipe-videos bucket" ON storage.objects
FOR DELETE USING (bucket_id = 'recipe-videos');

-- Normalize existing video paths (prefer double-prefix for legacy uploads)
-- Run comprehensive fixer instead of single hard-coded update
-- See: sql/fix_video_paths.sql
