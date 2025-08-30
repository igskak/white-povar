-- Normalize video file paths across recipes and recipe_videos
-- Goals:
-- 1) Make existing records match where files actually live today.
--    Old uploads stored objects at key 'recipe-videos/<recipe_id>/<filename>' INSIDE bucket 'recipe-videos',
--    so their correct public path becomes 'recipe-videos/recipe-videos/<recipe_id>/<filename>'.
-- 2) Keep new uploads canonical as 'recipe-videos/<recipe_id>/<filename>' (handled by backend change).
-- 3) Ensure missing bucket prefixes are added; do NOT strip double prefixes here.

BEGIN;

-- Optional: sync recipes.video_file_path from the latest active recipe_videos
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

-- Prefix with bucket if not already present (and not an absolute URL)
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

-- For legacy single-prefixed entries, add an extra 'recipe-videos/' so public URL points to existing object
UPDATE recipes
SET video_file_path = 'recipe-videos/' || video_file_path
WHERE video_file_path LIKE 'recipe-videos/%'
  AND video_file_path NOT LIKE 'recipe-videos/recipe-videos/%'
  AND EXISTS (
    SELECT 1
    FROM recipes r2
    WHERE r2.id = recipes.id
  );

UPDATE recipe_videos
SET file_path = 'recipe-videos/' || file_path
WHERE file_path LIKE 'recipe-videos/%'
  AND file_path NOT LIKE 'recipe-videos/recipe-videos/%';

COMMIT;

