-- CORE-03: private, tenant-scoped viewed/cooked history.
BEGIN;

CREATE TABLE IF NOT EXISTS public.user_recipe_history (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    recipe_id UUID NOT NULL REFERENCES public.recipes(id) ON DELETE CASCADE,
    viewed_at TIMESTAMP WITH TIME ZONE,
    cooked_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, chef_id, recipe_id)
);

CREATE INDEX IF NOT EXISTS idx_user_recipe_history_recent
    ON public.user_recipe_history (user_id, chef_id, updated_at DESC);

ALTER TABLE public.user_recipe_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS wp_user_recipe_history_select_own ON public.user_recipe_history;
CREATE POLICY wp_user_recipe_history_select_own
    ON public.user_recipe_history FOR SELECT TO authenticated
    USING (user_id = auth.uid());

COMMIT;
