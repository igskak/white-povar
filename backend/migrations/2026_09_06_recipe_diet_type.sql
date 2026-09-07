-- Discovery needs to answer "без м'яса", which is an exclusion over ingredient
-- rows. Evaluating that per query means scanning every candidate's ingredients
-- and post-filtering a page the planner already sized, so counts and paging go
-- wrong. This stores the answer once, as a derived column, and lets discovery
-- filter it with an ordinary indexed predicate.
--
-- The column is left NULL by this migration on purpose. It is populated by
-- `backend/tools/backfill_diet_type.py`, which shares its lexicon with the
-- application (`app/services/diet.py`) so the classification cannot drift
-- between SQL and Python. Until that backfill runs — and for content that
-- genuinely has no ingredients, such as techniques — the API resolves NULL
-- rows at read time, so the filter is correct before and after the backfill.
BEGIN;

ALTER TABLE public.recipes
    ADD COLUMN IF NOT EXISTS diet_type TEXT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'recipes_diet_type_check'
    ) THEN
        ALTER TABLE public.recipes
            ADD CONSTRAINT recipes_diet_type_check
            CHECK (diet_type IS NULL
                   OR diet_type IN ('meat', 'fish', 'vegetarian', 'vegan'));
    END IF;
END
$$;

COMMENT ON COLUMN public.recipes.diet_type IS
    'Derived by app/services/diet.py at write time. NULL means "not yet '
    'classified"; readers must treat it as unknown, never as plant-based.';

-- Discovery always filters within one tenant, so the tenant column leads.
CREATE INDEX IF NOT EXISTS idx_recipes_chef_diet_type
    ON public.recipes (chef_id, diet_type);

COMMIT;
