-- After moving legacy objects to canonical storage keys, strip the double prefix in DB

UPDATE recipes
SET video_file_path = REPLACE(video_file_path, 'recipe-videos/recipe-videos/', 'recipe-videos/')
WHERE video_file_path LIKE 'recipe-videos/recipe-videos/%';

UPDATE recipe_videos
SET file_path = REPLACE(file_path, 'recipe-videos/recipe-videos/', 'recipe-videos/')
WHERE file_path LIKE 'recipe-videos/recipe-videos/%';

