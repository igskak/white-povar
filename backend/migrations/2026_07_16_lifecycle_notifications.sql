-- LIFE-01: tenant-scoped lifecycle policy and device bindings.
BEGIN;

CREATE TABLE public.notification_preferences (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    marketing_consent BOOLEAN NOT NULL DEFAULT FALSE,
    new_content BOOLEAN NOT NULL DEFAULT FALSE,
    saved_recipe_reminders BOOLEAN NOT NULL DEFAULT FALSE,
    cooking_reminders BOOLEAN NOT NULL DEFAULT FALSE,
    timer_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    quiet_hours_start TIME,
    quiet_hours_end TIME,
    timezone TEXT NOT NULL DEFAULT 'Europe/Prague',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, chef_id),
    CONSTRAINT lifecycle_marketing_requires_consent CHECK (NOT new_content OR marketing_consent),
    CONSTRAINT lifecycle_quiet_hours_pair CHECK ((quiet_hours_start IS NULL) = (quiet_hours_end IS NULL))
);

CREATE TABLE public.push_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    token TEXT NOT NULL CHECK (char_length(token) BETWEEN 16 AND 4096),
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, chef_id, token)
);
CREATE INDEX push_devices_tenant_user_idx ON public.push_devices (chef_id, user_id);

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_devices ENABLE ROW LEVEL SECURITY;
-- Only the tenant-resolving API / lifecycle worker use service credentials.

-- A provider worker must select only eligible rows, render tenant branding
-- server-side, defer non-timer messages during quiet hours and atomically
-- record any frequency-cap decision.  It must not store receipt payloads.
CREATE TABLE public.lifecycle_delivery_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    category TEXT NOT NULL CHECK (category IN ('marketing', 'transactional', 'timer')),
    campaign_key TEXT NOT NULL CHECK (char_length(campaign_key) <= 80),
    deep_link_path TEXT NOT NULL CHECK (deep_link_path ~ '^/(recipes|collections|offers)/'),
    delivery_day DATE NOT NULL DEFAULT current_date,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX lifecycle_frequency_cap_idx
  ON public.lifecycle_delivery_log (user_id, chef_id, category, campaign_key, delivery_day);
ALTER TABLE public.lifecycle_delivery_log ENABLE ROW LEVEL SECURITY;
COMMIT;
