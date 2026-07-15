-- CORE-06: private tenant-scoped pantry and shopping list.
BEGIN;

CREATE TABLE IF NOT EXISTS public.pantry_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    quantity NUMERIC,
    unit TEXT,
    freshness_date TIMESTAMPTZ,
    source TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('manual', 'camera', 'voice')),
    confidence NUMERIC CHECK (confidence IS NULL OR confidence BETWEEN 0 AND 1),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (quantity IS NULL OR quantity > 0)
);
CREATE INDEX IF NOT EXISTS pantry_items_owner_tenant_idx ON public.pantry_items(user_id, chef_id);

CREATE TABLE IF NOT EXISTS public.shopping_list_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    recipe_id UUID REFERENCES public.recipes(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    quantity NUMERIC,
    unit TEXT,
    category TEXT NOT NULL DEFAULT 'Інше',
    checked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (quantity IS NULL OR quantity > 0)
);
CREATE INDEX IF NOT EXISTS shopping_list_items_owner_tenant_idx ON public.shopping_list_items(user_id, chef_id, checked);

ALTER TABLE public.pantry_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shopping_list_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY wp_pantry_items_own ON public.pantry_items FOR ALL TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY wp_shopping_list_items_own ON public.shopping_list_items FOR ALL TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
COMMIT;
