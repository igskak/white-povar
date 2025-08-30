-- Create storage bucket for recipe videos
INSERT INTO storage.buckets (id, name, public) 
VALUES ('recipe-videos', 'recipe-videos', true)
ON CONFLICT (id) DO NOTHING;

-- Create storage policy to allow public uploads
CREATE POLICY IF NOT EXISTS "Allow public uploads to recipe-videos bucket" ON storage.objects
FOR INSERT WITH CHECK (bucket_id = 'recipe-videos');

-- Create storage policy to allow public access to recipe-videos
CREATE POLICY IF NOT EXISTS "Allow public access to recipe-videos bucket" ON storage.objects
FOR SELECT USING (bucket_id = 'recipe-videos');

-- Create storage policy to allow public updates to recipe-videos
CREATE POLICY IF NOT EXISTS "Allow public updates to recipe-videos bucket" ON storage.objects
FOR UPDATE USING (bucket_id = 'recipe-videos');

-- Create storage policy to allow public deletes from recipe-videos
CREATE POLICY IF NOT EXISTS "Allow public deletes from recipe-videos bucket" ON storage.objects
FOR DELETE USING (bucket_id = 'recipe-videos');
