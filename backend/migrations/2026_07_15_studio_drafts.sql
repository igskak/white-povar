-- STUDIO-01: internal Studio membership and non-runtime BrandConfig drafts.
-- Published brand_configs remain immutable and are never edited in place.

BEGIN;

CREATE TABLE IF NOT EXISTS public.studio_memberships (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('editor', 'admin')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, chef_id)
);
CREATE INDEX IF NOT EXISTS idx_studio_memberships_chef_id ON public.studio_memberships (chef_id);
ALTER TABLE public.studio_memberships ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.studio_brand_drafts (
    chef_id UUID PRIMARY KEY REFERENCES public.chefs(id) ON DELETE CASCADE,
    config JSONB NOT NULL,
    version INTEGER NOT NULL DEFAULT 1 CHECK (version > 0),
    updated_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
ALTER TABLE public.studio_brand_drafts ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.save_studio_brand_draft(
    p_chef_id UUID,
    p_user_id UUID,
    p_config JSONB,
    p_expected_version INTEGER
)
RETURNS TABLE(config JSONB, version INTEGER, updated_at TIMESTAMP WITH TIME ZONE)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_current_version INTEGER;
BEGIN
    -- Serialising on the tenant makes both a first-draft insert and subsequent
    -- updates compare-and-swap operations.
    PERFORM id FROM chefs WHERE id = p_chef_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    SELECT d.version INTO v_current_version
    FROM studio_brand_drafts d WHERE d.chef_id = p_chef_id;
    IF v_current_version IS NULL THEN
        SELECT b.version INTO v_current_version
        FROM brand_configs b
        WHERE b.chef_id = p_chef_id AND b.status = 'published'
        ORDER BY b.version DESC LIMIT 1;
    END IF;

    IF v_current_version IS NULL OR v_current_version <> p_expected_version THEN
        RETURN;
    END IF;

    INSERT INTO studio_brand_drafts (chef_id, config, version, updated_by)
    VALUES (p_chef_id, p_config, p_expected_version + 1, p_user_id)
    ON CONFLICT (chef_id) DO UPDATE SET
        config = EXCLUDED.config,
        version = EXCLUDED.version,
        updated_by = EXCLUDED.updated_by,
        updated_at = NOW();

    RETURN QUERY SELECT d.config, d.version, d.updated_at
    FROM studio_brand_drafts d WHERE d.chef_id = p_chef_id;
END;
$$;
REVOKE ALL ON FUNCTION public.save_studio_brand_draft(UUID, UUID, JSONB, INTEGER) FROM PUBLIC;

COMMIT;
