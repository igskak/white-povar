-- Profile counters: the saved and cooked totals already have a home
-- (`user_favorites`, `user_recipe_history`), but a photo scan left no trace
-- once its results were rendered. This records one private, tenant-scoped row
-- per completed scan so the profile can count them.
BEGIN;

CREATE TABLE IF NOT EXISTS public.user_scan_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_scan_events_owner
    ON public.user_scan_events (user_id, chef_id, created_at DESC);

ALTER TABLE public.user_scan_events ENABLE ROW LEVEL SECURITY;

-- Reads stay owner-only and writes stay with the service role, matching
-- `user_recipe_history`: a client must not be able to inflate its own counter.
DROP POLICY IF EXISTS wp_user_scan_events_select_own ON public.user_scan_events;
CREATE POLICY wp_user_scan_events_select_own
    ON public.user_scan_events FOR SELECT TO authenticated
    USING (user_id = auth.uid());

COMMIT;
