-- SEC-01: tenant-scoped entitlements and RLS hardening.
-- Service-role API queries remain explicitly scoped by chef_id; these policies
-- protect direct authenticated/anon database access as a second boundary.
BEGIN;

CREATE TABLE IF NOT EXISTS public.tenant_entitlements (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    product_id TEXT NOT NULL DEFAULT 'subscription',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    expires_at TIMESTAMP WITH TIME ZONE,
    granted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, chef_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_tenant_entitlements_active
    ON public.tenant_entitlements (user_id, chef_id)
    WHERE is_active = TRUE;

ALTER TABLE public.tenant_entitlements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS wp_tenant_entitlements_select_own ON public.tenant_entitlements;
CREATE POLICY wp_tenant_entitlements_select_own
    ON public.tenant_entitlements FOR SELECT TO authenticated
    USING (user_id = auth.uid());

-- Public discovery is tenant-scoped by the API.  Direct database reads must
-- never reveal premium body; only owners or an active entitlement can select it.
DROP POLICY IF EXISTS wp_recipes_select_visible ON public.recipes;
CREATE POLICY wp_recipes_select_visible
    ON public.recipes FOR SELECT TO anon, authenticated
    USING (
        (is_public = TRUE AND is_premium = FALSE)
        OR EXISTS (
            SELECT 1 FROM public.users member
            WHERE member.id = auth.uid() AND member.chef_id = recipes.chef_id
        )
        OR (
            is_public = TRUE AND is_premium = TRUE
            AND EXISTS (
                SELECT 1 FROM public.tenant_entitlements entitlement
                WHERE entitlement.user_id = auth.uid()
                  AND entitlement.chef_id = recipes.chef_id
                  AND entitlement.is_active = TRUE
                  AND (entitlement.expires_at IS NULL OR entitlement.expires_at > now())
            )
        )
    );

COMMIT;
