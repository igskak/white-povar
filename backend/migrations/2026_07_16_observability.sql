-- OBS-01: consent-gated, tenant-isolated aggregate observability.
CREATE TABLE IF NOT EXISTS public.analytics_consents (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    analytics_consent BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, chef_id)
);

CREATE TABLE IF NOT EXISTS public.analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    name TEXT NOT NULL CHECK (name IN (
      'activation_completed', 'search_completed', 'voice_search_completed',
      'recipe_viewed', 'cooking_completed', 'recipe_saved', 'paywall_viewed',
      'purchase_confirmed')),
    outcome TEXT NOT NULL DEFAULT 'success' CHECK (outcome IN ('success', 'empty', 'cancelled', 'failed')),
    client_version TEXT CHECK (char_length(client_version) <= 40),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS analytics_events_tenant_funnel_idx
  ON public.analytics_events (chef_id, name, created_at DESC);

ALTER TABLE public.analytics_consents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;
-- There are intentionally no direct client policies: the API resolves tenant
-- and consent server-side.  Dashboard queries use a restricted service role.

CREATE OR REPLACE VIEW public.analytics_tenant_daily_funnel
WITH (security_invoker = true) AS
SELECT chef_id, date_trunc('day', created_at)::date AS day, name, outcome,
       count(*) AS event_count
FROM public.analytics_events
GROUP BY chef_id, date_trunc('day', created_at)::date, name, outcome;

-- Cost dashboard: only aggregate model usage; never prompts, completions or IDs.
CREATE TABLE IF NOT EXISTS public.ai_cost_daily (
    day DATE NOT NULL DEFAULT current_date,
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    model TEXT NOT NULL,
    request_count INTEGER NOT NULL DEFAULT 0 CHECK (request_count >= 0),
    input_tokens INTEGER NOT NULL DEFAULT 0 CHECK (input_tokens >= 0),
    output_tokens INTEGER NOT NULL DEFAULT 0 CHECK (output_tokens >= 0),
    PRIMARY KEY (day, chef_id, model)
);
ALTER TABLE public.ai_cost_daily ENABLE ROW LEVEL SECURITY;
