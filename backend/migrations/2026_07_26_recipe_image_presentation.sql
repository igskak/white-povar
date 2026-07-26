-- Complete Creator Studio recipe authoring and role-aware image presentation.
BEGIN;

ALTER TABLE public.recipes
    ADD COLUMN IF NOT EXISTS image_presentation JSONB;

ALTER TABLE public.studio_assets
    ADD COLUMN IF NOT EXISTS asset_kind TEXT NOT NULL DEFAULT 'brand',
    ADD COLUMN IF NOT EXISTS bucket_id TEXT NOT NULL DEFAULT 'studio-brand-assets';

ALTER TABLE public.studio_assets
    DROP CONSTRAINT IF EXISTS studio_assets_asset_kind_check;
ALTER TABLE public.studio_assets
    ADD CONSTRAINT studio_assets_asset_kind_check
    CHECK (asset_kind IN ('brand', 'recipe'));

UPDATE public.recipes
SET image_presentation = jsonb_build_object(
    'primary', jsonb_build_object(
        'url', image_url,
        'alt_text', title,
        'focal', jsonb_build_object('x', 0.5, 'y', 0.5)
    ),
    'featured', NULL,
    'detail', NULL
)
WHERE image_url IS NOT NULL
  AND image_presentation IS NULL;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'studio-content-assets',
    'studio-content-assets',
    true,
    12582912,
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET public = true,
    file_size_limit = 12582912,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

CREATE OR REPLACE FUNCTION public.studio_save_content(
    p_chef_id UUID,
    p_user_id UUID,
    p_content_id UUID,
    p_values JSONB
)
RETURNS SETOF public.recipes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    result public.recipes%ROWTYPE;
    scheduled_at TIMESTAMPTZ;
    ingredient JSONB;
    ingredient_index INTEGER := 0;
    unit_uuid UUID;
BEGIN
    IF p_content_id IS NULL THEN
        INSERT INTO recipes (
            chef_id, title, description, content_kind, difficulty_level,
            prep_time_minutes, cook_time_minutes, servings, instructions,
            instructions_structured, image_url, image_presentation, video_url,
            video_file_path, tags, is_featured, is_premium, is_public,
            category_id
        )
        VALUES (
            p_chef_id,
            p_values->>'title',
            p_values->>'description',
            p_values->>'content_kind',
            COALESCE((p_values->>'difficulty')::INTEGER, 1),
            COALESCE((p_values->>'prep_time_minutes')::INTEGER, 0),
            COALESCE((p_values->>'cook_time_minutes')::INTEGER, 0),
            COALESCE((p_values->>'servings')::INTEGER, 1),
            COALESCE(array_to_string(
                ARRAY(
                    SELECT jsonb_array_elements_text(
                        COALESCE(p_values->'instructions', '[]'::JSONB)
                    )
                ),
                E'\n'
            ), ''),
            COALESCE(p_values->'instructions', '[]'::JSONB),
            p_values->>'image_url',
            p_values->'image_presentation',
            p_values->>'video_url',
            p_values->>'video_file_path',
            ARRAY(
                SELECT jsonb_array_elements_text(
                    COALESCE(p_values->'tags', '[]'::JSONB)
                )
            ),
            COALESCE((p_values->>'is_featured')::BOOLEAN, false),
            COALESCE((p_values->>'is_premium')::BOOLEAN, false),
            false,
            COALESCE(
                NULLIF(p_values->>'category_id', '')::UUID,
                '20000000-0000-0000-0000-000000000099'::UUID
            )
        )
        RETURNING * INTO result;
    ELSE
        UPDATE recipes
        SET title = p_values->>'title',
            description = p_values->>'description',
            content_kind = p_values->>'content_kind',
            difficulty_level = COALESCE(
                (p_values->>'difficulty')::INTEGER, 1),
            prep_time_minutes = COALESCE(
                (p_values->>'prep_time_minutes')::INTEGER, 0),
            cook_time_minutes = COALESCE(
                (p_values->>'cook_time_minutes')::INTEGER, 0),
            servings = COALESCE((p_values->>'servings')::INTEGER, 1),
            instructions = COALESCE(array_to_string(
                ARRAY(
                    SELECT jsonb_array_elements_text(
                        COALESCE(p_values->'instructions', '[]'::JSONB)
                    )
                ),
                E'\n'
            ), ''),
            instructions_structured = COALESCE(
                p_values->'instructions', '[]'::JSONB),
            image_url = p_values->>'image_url',
            image_presentation = p_values->'image_presentation',
            video_url = p_values->>'video_url',
            video_file_path = p_values->>'video_file_path',
            tags = ARRAY(
                SELECT jsonb_array_elements_text(
                    COALESCE(p_values->'tags', '[]'::JSONB)
                )
            ),
            is_featured = COALESCE(
                (p_values->>'is_featured')::BOOLEAN, false),
            is_premium = COALESCE(
                (p_values->>'is_premium')::BOOLEAN, false),
            category_id = COALESCE(
                NULLIF(p_values->>'category_id', '')::UUID,
                '20000000-0000-0000-0000-000000000099'::UUID
            ),
            updated_at = now()
        WHERE id = p_content_id
          AND chef_id = p_chef_id
        RETURNING * INTO result;
        IF NOT FOUND THEN
            RETURN;
        END IF;
        DELETE FROM recipe_ingredients WHERE recipe_id = result.id;
    END IF;

    FOR ingredient IN
        SELECT *
        FROM jsonb_array_elements(
            COALESCE(p_values->'ingredients', '[]'::JSONB)
        )
    LOOP
        unit_uuid := CASE lower(trim(ingredient->>'unit'))
            WHEN 'g' THEN '00000000-0000-0000-0000-000000000001'::UUID
            WHEN 'г' THEN '00000000-0000-0000-0000-000000000001'::UUID
            WHEN 'kg' THEN '00000000-0000-0000-0000-000000000002'::UUID
            WHEN 'кг' THEN '00000000-0000-0000-0000-000000000002'::UUID
            WHEN 'ml' THEN '00000000-0000-0000-0000-000000000010'::UUID
            WHEN 'мл' THEN '00000000-0000-0000-0000-000000000010'::UUID
            WHEN 'l' THEN '00000000-0000-0000-0000-000000000011'::UUID
            WHEN 'л' THEN '00000000-0000-0000-0000-000000000011'::UUID
            WHEN 'piece' THEN '00000000-0000-0000-0000-000000000020'::UUID
            WHEN 'шт' THEN '00000000-0000-0000-0000-000000000020'::UUID
            WHEN 'шт.' THEN '00000000-0000-0000-0000-000000000020'::UUID
            WHEN 'cup' THEN '00000000-0000-0000-0000-000000000021'::UUID
            WHEN 'tbsp' THEN '00000000-0000-0000-0000-000000000031'::UUID
            WHEN 'ст. л.' THEN '00000000-0000-0000-0000-000000000031'::UUID
            WHEN 'tsp' THEN '00000000-0000-0000-0000-000000000032'::UUID
            WHEN 'ч. л.' THEN '00000000-0000-0000-0000-000000000032'::UUID
            ELSE NULL
        END;
        INSERT INTO recipe_ingredients (
            recipe_id, display_name, amount, unit_id, preparation_notes,
            sort_order
        )
        VALUES (
            result.id,
            ingredient->>'name',
            NULLIF(ingredient->>'amount', '')::NUMERIC,
            unit_uuid,
            NULLIF(ingredient->>'notes', ''),
            ingredient_index
        );
        ingredient_index := ingredient_index + 1;
    END LOOP;

    scheduled_at := NULLIF(p_values->>'publish_at', '')::TIMESTAMPTZ;
    IF scheduled_at > now() THEN
        INSERT INTO studio_scheduled_publications (
            chef_id, entity_type, entity_id, publish_at, created_by
        )
        VALUES (
            p_chef_id, 'content', result.id, scheduled_at, p_user_id
        )
        ON CONFLICT (entity_type, entity_id)
        DO UPDATE SET
            publish_at = EXCLUDED.publish_at,
            created_by = EXCLUDED.created_by;
    END IF;

    INSERT INTO studio_content_audit (
        chef_id, actor_id, entity_type, entity_id, action, details
    )
    VALUES (
        p_chef_id,
        p_user_id,
        'content',
        result.id,
        CASE
            WHEN p_content_id IS NULL THEN 'created_draft'
            ELSE 'updated_draft'
        END,
        jsonb_build_object('scheduledAt', scheduled_at)
    );
    RETURN NEXT result;
END;
$$;

CREATE OR REPLACE FUNCTION public.studio_publish_content(
    p_chef_id UUID,
    p_user_id UUID,
    p_content_id UUID
)
RETURNS SETOF public.recipes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    result public.recipes%ROWTYPE;
BEGIN
    IF EXISTS (
        SELECT 1
        FROM recipes recipe
        WHERE recipe.id = p_content_id
          AND recipe.chef_id = p_chef_id
          AND recipe.content_kind = 'recipe'
          AND (
              recipe.image_url IS NULL
              OR recipe.instructions_structured IS NULL
              OR jsonb_array_length(recipe.instructions_structured) = 0
              OR NOT EXISTS (
                  SELECT 1
                  FROM recipe_ingredients ingredient
                  WHERE ingredient.recipe_id = recipe.id
              )
          )
    ) THEN
        RAISE EXCEPTION 'Recipe is incomplete and cannot be published';
    END IF;

    UPDATE recipes
    SET is_public = true,
        updated_at = now()
    WHERE id = p_content_id
      AND chef_id = p_chef_id
    RETURNING * INTO result;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    DELETE FROM studio_scheduled_publications
    WHERE entity_type = 'content'
      AND entity_id = result.id;
    INSERT INTO studio_content_audit (
        chef_id, actor_id, entity_type, entity_id, action
    )
    VALUES (
        p_chef_id, p_user_id, 'content', result.id, 'published'
    );
    RETURN NEXT result;
END;
$$;

CREATE OR REPLACE FUNCTION public.purge_expired_studio_asset_uploads()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage
AS $$
DECLARE
    asset RECORD;
    removed INTEGER := 0;
BEGIN
    FOR asset IN
        DELETE FROM public.studio_assets
        WHERE state = 'uploading'
          AND created_at < NOW() - INTERVAL '24 hours'
        RETURNING source_path, bucket_id
    LOOP
        DELETE FROM storage.objects
        WHERE bucket_id = asset.bucket_id
          AND name = asset.source_path;
        removed := removed + 1;
    END LOOP;
    RETURN removed;
END;
$$;

COMMIT;
