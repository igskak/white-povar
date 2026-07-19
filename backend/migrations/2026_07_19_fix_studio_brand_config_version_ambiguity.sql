-- Fix the Studio publish/rollback functions shipped by STUDIO-03.
-- RETURNS TABLE creates an output variable named `version`; unqualified
-- `MAX(version)` therefore becomes ambiguous in PL/pgSQL at runtime.
BEGIN;

CREATE OR REPLACE FUNCTION public.publish_studio_brand_draft(p_chef_id UUID, p_user_id UUID, p_expected_version INTEGER)
RETURNS TABLE(version INTEGER, published_at TIMESTAMP WITH TIME ZONE)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_config JSONB; v_version INTEGER; v_now TIMESTAMP WITH TIME ZONE := NOW();
BEGIN
    SELECT d.config INTO v_config
    FROM studio_brand_drafts d
    WHERE d.chef_id = p_chef_id AND d.version = p_expected_version
    FOR UPDATE;
    IF v_config IS NULL THEN RETURN; END IF;
    UPDATE brand_configs b SET status = 'archived'
    WHERE b.chef_id = p_chef_id AND b.status = 'published';
    SELECT COALESCE(MAX(b.version), 0) + 1 INTO v_version
    FROM brand_configs b WHERE b.chef_id = p_chef_id;
    INSERT INTO brand_configs (chef_id, version, status, config, created_by, published_at)
    VALUES (p_chef_id, v_version, 'published', v_config, p_user_id, v_now);
    INSERT INTO studio_audit_log (chef_id, actor_id, action, subject_type, metadata)
    VALUES (p_chef_id, p_user_id, 'config_published', 'brand_config', jsonb_build_object('version', v_version, 'draftVersion', p_expected_version));
    RETURN QUERY SELECT v_version, v_now;
END; $$;

CREATE OR REPLACE FUNCTION public.rollback_studio_brand_config(p_chef_id UUID, p_user_id UUID, p_source_version INTEGER)
RETURNS TABLE(version INTEGER, published_at TIMESTAMP WITH TIME ZONE)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_config JSONB; v_version INTEGER; v_now TIMESTAMP WITH TIME ZONE := NOW();
BEGIN
    SELECT b.config INTO v_config FROM brand_configs b
    WHERE b.chef_id = p_chef_id AND b.version = p_source_version;
    IF v_config IS NULL THEN RETURN; END IF;
    UPDATE brand_configs b SET status = 'archived'
    WHERE b.chef_id = p_chef_id AND b.status = 'published';
    SELECT COALESCE(MAX(b.version), 0) + 1 INTO v_version
    FROM brand_configs b WHERE b.chef_id = p_chef_id;
    INSERT INTO brand_configs (chef_id, version, status, config, created_by, published_at)
    VALUES (p_chef_id, v_version, 'published', v_config, p_user_id, v_now);
    INSERT INTO studio_audit_log (chef_id, actor_id, action, subject_type, metadata)
    VALUES (p_chef_id, p_user_id, 'config_rolled_back', 'brand_config', jsonb_build_object('version', v_version, 'sourceVersion', p_source_version));
    RETURN QUERY SELECT v_version, v_now;
END; $$;

REVOKE ALL ON FUNCTION public.publish_studio_brand_draft(UUID, UUID, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rollback_studio_brand_config(UUID, UUID, INTEGER) FROM PUBLIC;

COMMIT;
