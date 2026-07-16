-- GROW-01: private, tenant-scoped weekly recipe calendar.
BEGIN;

CREATE TABLE IF NOT EXISTS public.menu_plan_slots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    planned_for DATE NOT NULL,
    recipe_id UUID NOT NULL REFERENCES public.recipes(id) ON DELETE CASCADE,
    collection_id UUID REFERENCES public.collections(id) ON DELETE SET NULL,
    servings INTEGER NOT NULL CHECK (servings BETWEEN 1 AND 100),
    position INTEGER NOT NULL DEFAULT 0 CHECK (position >= 0),
    title TEXT NOT NULL,
    is_premium BOOLEAN NOT NULL DEFAULT FALSE,
    image_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS menu_plan_slots_owner_week_idx
    ON public.menu_plan_slots(user_id, chef_id, planned_for, position);

ALTER TABLE public.menu_plan_slots ENABLE ROW LEVEL SECURITY;
CREATE POLICY wp_menu_plan_slots_own ON public.menu_plan_slots FOR ALL TO authenticated
    USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
COMMIT;
