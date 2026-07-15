-- Studio-00: transactional, forward-only BrandConfig publishing.
-- Config JSON is validated by the CLI before this function is called. The
-- database function owns version allocation and status transitions so a
-- published version is immutable and there can never be two current rows.

BEGIN;

CREATE OR REPLACE FUNCTION public.publish_brand_config(
    p_tenant_slug TEXT,
    p_config JSONB,
    p_created_by UUID DEFAULT NULL
)
RETURNS TABLE(version INTEGER, published_at TIMESTAMP WITH TIME ZONE)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_chef_id UUID;
    v_version INTEGER;
    v_published_at TIMESTAMP WITH TIME ZONE := NOW();
BEGIN
    SELECT id INTO v_chef_id
    FROM chefs
    WHERE slug = p_tenant_slug AND is_active = TRUE
    FOR UPDATE;

    IF v_chef_id IS NULL THEN
        RAISE EXCEPTION 'active tenant % was not found', p_tenant_slug
            USING ERRCODE = 'P0002';
    END IF;

    UPDATE brand_configs
    SET status = 'archived'
    WHERE chef_id = v_chef_id AND status = 'published';

    SELECT COALESCE(MAX(brand_configs.version), 0) + 1 INTO v_version
    FROM brand_configs
    WHERE chef_id = v_chef_id;

    INSERT INTO brand_configs (chef_id, version, status, config, created_by, published_at)
    VALUES (v_chef_id, v_version, 'published', p_config, p_created_by, v_published_at);

    RETURN QUERY SELECT v_version, v_published_at;
END;
$$;

CREATE OR REPLACE FUNCTION public.rollback_brand_config(
    p_tenant_slug TEXT,
    p_version INTEGER
)
RETURNS TABLE(version INTEGER, published_at TIMESTAMP WITH TIME ZONE)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_chef_id UUID;
    v_config JSONB;
BEGIN
    SELECT id INTO v_chef_id
    FROM chefs
    WHERE slug = p_tenant_slug AND is_active = TRUE
    FOR UPDATE;

    IF v_chef_id IS NULL THEN
        RAISE EXCEPTION 'active tenant % was not found', p_tenant_slug
            USING ERRCODE = 'P0002';
    END IF;

    SELECT config INTO v_config
    FROM brand_configs
    WHERE chef_id = v_chef_id AND version = p_version;

    IF v_config IS NULL THEN
        RAISE EXCEPTION 'BrandConfig version % does not exist for tenant %', p_version, p_tenant_slug
            USING ERRCODE = 'P0002';
    END IF;

    -- Rollback creates a new immutable published version; it never mutates or
    -- reactivates historical config JSON.
    RETURN QUERY
    SELECT * FROM public.publish_brand_config(p_tenant_slug, v_config, NULL);
END;
$$;

REVOKE ALL ON FUNCTION public.publish_brand_config(TEXT, JSONB, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rollback_brand_config(TEXT, INTEGER) FROM PUBLIC;

COMMIT;
