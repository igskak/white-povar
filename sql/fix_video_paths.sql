-- One-off fixer script to normalize existing video paths
-- Usage: run in Supabase SQL editor or psql

-- Ensure bucket prefix exists
UPDATE recipes
SET video_file_path = 'recipe-videos/' || video_file_path
WHERE video_file_path IS NOT NULL
  AND video_file_path NOT LIKE 'http%'
  AND video_file_path NOT LIKE 'recipe-videos/%';

UPDATE recipe_videos
SET file_path = 'recipe-videos/' || file_path
WHERE file_path IS NOT NULL
  AND file_path NOT LIKE 'http%'
  AND file_path NOT LIKE 'recipe-videos/%';

-- For legacy entries that were stored as single prefix but objects live under double prefix,
-- add an extra 'recipe-videos/' so the public URL matches the real object locations.
UPDATE recipes
SET video_file_path = 'recipe-videos/' || video_file_path
WHERE video_file_path LIKE 'recipe-videos/%'
  AND video_file_path NOT LIKE 'recipe-videos/recipe-videos/%';

UPDATE recipe_videos
SET file_path = 'recipe-videos/' || file_path
WHERE file_path LIKE 'recipe-videos/%'
  AND file_path NOT LIKE 'recipe-videos/recipe-videos/%';

-- Optionally sync recipes.video_file_path from latest active video
WITH latest AS (
  SELECT DISTINCT ON (recipe_id)
         recipe_id,
         file_path
  FROM recipe_videos
  WHERE is_active = TRUE
  ORDER BY recipe_id, uploaded_at DESC
)
UPDATE recipes r
SET video_file_path = l.file_path
FROM latest l
WHERE r.id = l.recipe_id;
