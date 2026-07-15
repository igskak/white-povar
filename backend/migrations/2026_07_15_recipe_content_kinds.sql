-- COL-01: content kinds reuse the existing recipes infrastructure.
BEGIN;

ALTER TABLE public.recipes
    ADD COLUMN IF NOT EXISTS content_kind TEXT NOT NULL DEFAULT 'recipe';

ALTER TABLE public.recipes
    DROP CONSTRAINT IF EXISTS recipes_content_kind_check;

ALTER TABLE public.recipes
    ADD CONSTRAINT recipes_content_kind_check
    CHECK (content_kind IN ('recipe', 'technique', 'process', 'video'));

CREATE INDEX IF NOT EXISTS recipes_chef_content_kind_idx
    ON public.recipes (chef_id, content_kind);

COMMIT;
