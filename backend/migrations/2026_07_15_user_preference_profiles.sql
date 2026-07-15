-- CORE-05: consented, tenant-scoped personalization inputs.
BEGIN;

CREATE TABLE IF NOT EXISTS public.user_preference_profiles (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    diets TEXT[] NOT NULL DEFAULT '{}',
    allergens TEXT[] NOT NULL DEFAULT '{}',
    dislikes TEXT[] NOT NULL DEFAULT '{}',
    preferred_max_total_time INTEGER,
    equipment TEXT[] NOT NULL DEFAULT '{}',
    household_size INTEGER,
    personalization_consent BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, chef_id),
    CONSTRAINT preference_time_range CHECK (
        preferred_max_total_time IS NULL OR preferred_max_total_time BETWEEN 1 AND 1440
    ),
    CONSTRAINT preference_household_range CHECK (
        household_size IS NULL OR household_size BETWEEN 1 AND 30
    )
);

ALTER TABLE public.user_preference_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS wp_user_preference_profiles_select_own ON public.user_preference_profiles;
CREATE POLICY wp_user_preference_profiles_select_own
    ON public.user_preference_profiles FOR SELECT TO authenticated
    USING (user_id = auth.uid());

COMMIT;
