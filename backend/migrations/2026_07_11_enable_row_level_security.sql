-- Forward-only migration: establish the baseline Supabase Row Level Security model.
--
-- Identity facts from database_schema.sql:
--   * public.users.id is the Supabase Auth user id (auth.uid()).
--   * recipe_ingredients, recipe_nutrition, and recipe_videos inherit visibility and
--     access from their parent recipe through recipe_id.
--   * public.recipes.chef_id REFERENCES public.chefs(id).
--
-- This migration adds public.users.chef_id as the explicit chef membership relation.
-- Multiple users may belong to the same chef. Existing/new users with chef_id NULL
-- remain fail-closed for recipe mutations until a trusted backend/admin assigns them.
--
-- IMPORTANT: Supabase's service_role has BYPASSRLS. It remains able to perform
-- trusted backend, ingestion, billing, and administrative work after this migration.
-- Never expose the service-role key to a browser or mobile client. RLS protects
-- requests made as anon/authenticated; it is not a boundary around service_role.

BEGIN;

-- -----------------------------------------------------------------------------
-- Schema gaps required for enforceable ownership and persisted favorites
-- -----------------------------------------------------------------------------

ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS chef_id UUID
    REFERENCES public.chefs(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_users_chef_id ON public.users(chef_id);

CREATE TABLE IF NOT EXISTS public.user_favorites (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    recipe_id UUID NOT NULL REFERENCES public.recipes(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, recipe_id)
);

CREATE INDEX IF NOT EXISTS idx_user_favorites_recipe_id
    ON public.user_favorites(recipe_id);

-- -----------------------------------------------------------------------------
-- User profiles
-- -----------------------------------------------------------------------------

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS wp_users_select_own ON public.users;
CREATE POLICY wp_users_select_own
    ON public.users
    FOR SELECT
    TO authenticated
    USING (id = auth.uid());

-- No client INSERT/UPDATE/DELETE policy is intentional. User provisioning and
-- profile synchronization currently run through the trusted backend service role.
-- This also prevents a client from changing subscription columns directly when
-- the premium subscription migration is installed.

-- -----------------------------------------------------------------------------
-- Favorites: each authenticated user controls only their own saved-recipe rows.
-- -----------------------------------------------------------------------------

ALTER TABLE public.user_favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS wp_user_favorites_select_own ON public.user_favorites;
CREATE POLICY wp_user_favorites_select_own
    ON public.user_favorites
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS wp_user_favorites_insert_own ON public.user_favorites;
CREATE POLICY wp_user_favorites_insert_own
    ON public.user_favorites
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS wp_user_favorites_delete_own ON public.user_favorites;
CREATE POLICY wp_user_favorites_delete_own
    ON public.user_favorites
    FOR DELETE
    TO authenticated
    USING (user_id = auth.uid());

-- UPDATE is intentionally omitted: the composite key is immutable. Replacing a
-- favorite is expressed as DELETE plus INSERT, both scoped to auth.uid().

-- -----------------------------------------------------------------------------
-- Recipes
-- -----------------------------------------------------------------------------

ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS wp_recipes_select_visible ON public.recipes;

-- Premium columns were added by a separate migration and are not part of the base
-- database_schema.sql. Build the SELECT policy against the schema that is actually
-- installed so this migration works both before and after that additive migration.
DO $migration$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE attrelid = 'public.recipes'::regclass
          AND attname = 'is_premium'
          AND NOT attisdropped
    ) AND NOT EXISTS (
        SELECT required_column.name
        FROM unnest(ARRAY[
            'subscription_tier',
            'subscription_status',
            'subscription_end_date'
        ]) AS required_column(name)
        WHERE NOT EXISTS (
            SELECT 1
            FROM pg_attribute
            WHERE attrelid = 'public.users'::regclass
              AND attname = required_column.name
              AND NOT attisdropped
        )
    ) THEN
        EXECUTE $policy$
            CREATE POLICY wp_recipes_select_visible
                ON public.recipes
                FOR SELECT
                TO anon, authenticated
                USING (
                    EXISTS (
                        SELECT 1
                        FROM public.users AS member
                        WHERE member.id = auth.uid()
                          AND member.chef_id = recipes.chef_id
                    )
                    OR (
                        is_public = TRUE
                        AND (
                            is_premium = FALSE
                            OR EXISTS (
                                SELECT 1
                                FROM public.users AS viewer
                                WHERE viewer.id = auth.uid()
                                  AND viewer.subscription_tier::text = 'premium'
                                  AND viewer.subscription_status::text = 'active'
                                  AND (
                                      viewer.subscription_end_date IS NULL
                                      OR viewer.subscription_end_date > now()
                                  )
                            )
                        )
                    )
                )
        $policy$;
    ELSIF EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE attrelid = 'public.recipes'::regclass
          AND attname = 'is_premium'
          AND NOT attisdropped
    ) THEN
        -- If premium content exists but the subscription model is incomplete,
        -- expose only explicitly non-premium public recipes (fail closed).
        EXECUTE $policy$
            CREATE POLICY wp_recipes_select_visible
                ON public.recipes
                FOR SELECT
                TO anon, authenticated
                USING (
                    (is_public = TRUE AND is_premium = FALSE)
                    OR EXISTS (
                        SELECT 1
                        FROM public.users AS member
                        WHERE member.id = auth.uid()
                          AND member.chef_id = recipes.chef_id
                    )
                )
        $policy$;
    ELSE
        EXECUTE $policy$
            CREATE POLICY wp_recipes_select_visible
                ON public.recipes
                FOR SELECT
                TO anon, authenticated
                USING (
                    is_public = TRUE
                    OR EXISTS (
                        SELECT 1
                        FROM public.users AS member
                        WHERE member.id = auth.uid()
                          AND member.chef_id = recipes.chef_id
                    )
                )
        $policy$;
    END IF;
END
$migration$;

DROP POLICY IF EXISTS wp_recipes_insert_own ON public.recipes;
CREATE POLICY wp_recipes_insert_own
    ON public.recipes
    FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM public.users AS member
            WHERE member.id = auth.uid()
              AND member.chef_id = recipes.chef_id
        )
    );

DROP POLICY IF EXISTS wp_recipes_update_own ON public.recipes;
CREATE POLICY wp_recipes_update_own
    ON public.recipes
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users AS member
            WHERE member.id = auth.uid()
              AND member.chef_id = recipes.chef_id
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users AS member
            WHERE member.id = auth.uid()
              AND member.chef_id = recipes.chef_id
        )
    );

DROP POLICY IF EXISTS wp_recipes_delete_own ON public.recipes;
CREATE POLICY wp_recipes_delete_own
    ON public.recipes
    FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users AS member
            WHERE member.id = auth.uid()
              AND member.chef_id = recipes.chef_id
        )
    );

-- Both USING and WITH CHECK bind updates to the authenticated user's assigned chef,
-- preventing a recipe from being transferred to a chef the user does not belong to.

-- -----------------------------------------------------------------------------
-- Recipe ingredients: visibility and writes inherit the parent recipe boundary.
-- -----------------------------------------------------------------------------

ALTER TABLE public.recipe_ingredients ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS wp_recipe_ingredients_select_visible ON public.recipe_ingredients;
CREATE POLICY wp_recipe_ingredients_select_visible
    ON public.recipe_ingredients
    FOR SELECT
    TO anon, authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.recipes AS parent
            WHERE parent.id = recipe_ingredients.recipe_id
        )
    );

DROP POLICY IF EXISTS wp_recipe_ingredients_insert_own ON public.recipe_ingredients;
CREATE POLICY wp_recipe_ingredients_insert_own
    ON public.recipe_ingredients
    FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM public.recipes AS parent
            JOIN public.users AS member ON member.chef_id = parent.chef_id
            WHERE parent.id = recipe_ingredients.recipe_id
              AND member.id = auth.uid()
        )
    );

DROP POLICY IF EXISTS wp_recipe_ingredients_update_own ON public.recipe_ingredients;
CREATE POLICY wp_recipe_ingredients_update_own
    ON public.recipe_ingredients
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.recipes AS parent
            JOIN public.users AS member ON member.chef_id = parent.chef_id
            WHERE parent.id = recipe_ingredients.recipe_id
              AND member.id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM public.recipes AS parent
            JOIN public.users AS member ON member.chef_id = parent.chef_id
            WHERE parent.id = recipe_ingredients.recipe_id
              AND member.id = auth.uid()
        )
    );

DROP POLICY IF EXISTS wp_recipe_ingredients_delete_own ON public.recipe_ingredients;
CREATE POLICY wp_recipe_ingredients_delete_own
    ON public.recipe_ingredients
    FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.recipes AS parent
            JOIN public.users AS member ON member.chef_id = parent.chef_id
            WHERE parent.id = recipe_ingredients.recipe_id
              AND member.id = auth.uid()
        )
    );

-- -----------------------------------------------------------------------------
-- Recipe nutrition: visibility and writes inherit the parent recipe boundary.
-- -----------------------------------------------------------------------------

ALTER TABLE public.recipe_nutrition ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS wp_recipe_nutrition_select_visible ON public.recipe_nutrition;
CREATE POLICY wp_recipe_nutrition_select_visible
    ON public.recipe_nutrition
    FOR SELECT
    TO anon, authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.recipes AS parent
            WHERE parent.id = recipe_nutrition.recipe_id
        )
    );

DROP POLICY IF EXISTS wp_recipe_nutrition_insert_own ON public.recipe_nutrition;
CREATE POLICY wp_recipe_nutrition_insert_own
    ON public.recipe_nutrition
    FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM public.recipes AS parent
            JOIN public.users AS member ON member.chef_id = parent.chef_id
            WHERE parent.id = recipe_nutrition.recipe_id
              AND member.id = auth.uid()
        )
    );

DROP POLICY IF EXISTS wp_recipe_nutrition_update_own ON public.recipe_nutrition;
CREATE POLICY wp_recipe_nutrition_update_own
    ON public.recipe_nutrition
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.recipes AS parent
            JOIN public.users AS member ON member.chef_id = parent.chef_id
            WHERE parent.id = recipe_nutrition.recipe_id
              AND member.id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM public.recipes AS parent
            JOIN public.users AS member ON member.chef_id = parent.chef_id
            WHERE parent.id = recipe_nutrition.recipe_id
              AND member.id = auth.uid()
        )
    );

DROP POLICY IF EXISTS wp_recipe_nutrition_delete_own ON public.recipe_nutrition;
CREATE POLICY wp_recipe_nutrition_delete_own
    ON public.recipe_nutrition
    FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.recipes AS parent
            JOIN public.users AS member ON member.chef_id = parent.chef_id
            WHERE parent.id = recipe_nutrition.recipe_id
              AND member.id = auth.uid()
        )
    );

-- -----------------------------------------------------------------------------
-- Recipe videos follow the same parent recipe boundary.
-- -----------------------------------------------------------------------------

ALTER TABLE public.recipe_videos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS wp_recipe_videos_select_visible ON public.recipe_videos;
CREATE POLICY wp_recipe_videos_select_visible
    ON public.recipe_videos
    FOR SELECT
    TO anon, authenticated
    USING (
        is_active = TRUE
        AND EXISTS (
            SELECT 1 FROM public.recipes AS parent
            WHERE parent.id = recipe_videos.recipe_id
        )
    );

DROP POLICY IF EXISTS wp_recipe_videos_insert_own ON public.recipe_videos;
CREATE POLICY wp_recipe_videos_insert_own
    ON public.recipe_videos
    FOR INSERT
    TO authenticated
    WITH CHECK (
        uploaded_by = auth.uid()
        AND EXISTS (
            SELECT 1
            FROM public.recipes AS parent
            JOIN public.users AS member ON member.chef_id = parent.chef_id
            WHERE parent.id = recipe_videos.recipe_id
              AND member.id = auth.uid()
        )
    );

DROP POLICY IF EXISTS wp_recipe_videos_update_own ON public.recipe_videos;
CREATE POLICY wp_recipe_videos_update_own
    ON public.recipe_videos
    FOR UPDATE
    TO authenticated
    USING (
        uploaded_by = auth.uid()
        AND EXISTS (
            SELECT 1
            FROM public.recipes AS parent
            JOIN public.users AS member ON member.chef_id = parent.chef_id
            WHERE parent.id = recipe_videos.recipe_id
              AND member.id = auth.uid()
        )
    )
    WITH CHECK (
        uploaded_by = auth.uid()
        AND EXISTS (
            SELECT 1
            FROM public.recipes AS parent
            JOIN public.users AS member ON member.chef_id = parent.chef_id
            WHERE parent.id = recipe_videos.recipe_id
              AND member.id = auth.uid()
        )
    );

DROP POLICY IF EXISTS wp_recipe_videos_delete_own ON public.recipe_videos;
CREATE POLICY wp_recipe_videos_delete_own
    ON public.recipe_videos
    FOR DELETE
    TO authenticated
    USING (
        uploaded_by = auth.uid()
        AND EXISTS (
            SELECT 1
            FROM public.recipes AS parent
            JOIN public.users AS member ON member.chef_id = parent.chef_id
            WHERE parent.id = recipe_videos.recipe_id
              AND member.id = auth.uid()
        )
    );

-- uploaded_by is immutable through client RLS in practice: only the original
-- uploader may mutate/delete its row, and WITH CHECK keeps that identity bound.

-- -----------------------------------------------------------------------------
-- Public read-only catalogue data. No client mutation policies are created.
-- -----------------------------------------------------------------------------

ALTER TABLE public.chefs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ingredient_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.base_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipe_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS wp_chefs_select_active ON public.chefs;
CREATE POLICY wp_chefs_select_active ON public.chefs
    FOR SELECT TO anon, authenticated USING (is_active = TRUE);

DROP POLICY IF EXISTS wp_units_select_active ON public.units;
CREATE POLICY wp_units_select_active ON public.units
    FOR SELECT TO anon, authenticated USING (is_active = TRUE);

DROP POLICY IF EXISTS wp_ingredient_categories_select_active ON public.ingredient_categories;
CREATE POLICY wp_ingredient_categories_select_active ON public.ingredient_categories
    FOR SELECT TO anon, authenticated USING (is_active = TRUE);

DROP POLICY IF EXISTS wp_base_ingredients_select_active ON public.base_ingredients;
CREATE POLICY wp_base_ingredients_select_active ON public.base_ingredients
    FOR SELECT TO anon, authenticated USING (is_active = TRUE);

DROP POLICY IF EXISTS wp_recipe_categories_select_active ON public.recipe_categories;
CREATE POLICY wp_recipe_categories_select_active ON public.recipe_categories
    FOR SELECT TO anon, authenticated USING (is_active = TRUE);

-- -----------------------------------------------------------------------------
-- Optional premium tables: users can read their own billing history/audit trail,
-- but all writes remain service-role-only. These blocks are conditional because
-- the tables are created by a separate migration, not database_schema.sql.
-- -----------------------------------------------------------------------------

DO $migration$
BEGIN
    IF to_regclass('public.subscriptions') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY';
        EXECUTE 'DROP POLICY IF EXISTS wp_subscriptions_select_own ON public.subscriptions';
        EXECUTE $policy$
            CREATE POLICY wp_subscriptions_select_own
                ON public.subscriptions
                FOR SELECT
                TO authenticated
                USING (user_id = auth.uid())
        $policy$;
    END IF;

    IF to_regclass('public.subscription_events') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.subscription_events ENABLE ROW LEVEL SECURITY';
        EXECUTE 'DROP POLICY IF EXISTS wp_subscription_events_select_own ON public.subscription_events';
        EXECUTE $policy$
            CREATE POLICY wp_subscription_events_select_own
                ON public.subscription_events
                FOR SELECT
                TO authenticated
                USING (user_id = auth.uid())
        $policy$;
    END IF;
END
$migration$;

-- -----------------------------------------------------------------------------
-- Internal ingestion and fingerprinting tables: service role only.
-- Enabling RLS without anon/authenticated policies intentionally denies clients.
-- -----------------------------------------------------------------------------

ALTER TABLE public.ingestion_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipe_fingerprints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ingestion_reviews ENABLE ROW LEVEL SECURITY;

COMMIT;
