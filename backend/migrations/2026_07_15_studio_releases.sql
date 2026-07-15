-- STUDIO-03: immutable config publication plus operator-owned release tracking.
-- These jobs deliberately record requests/statuses; they do not pretend to
-- deploy web assets or submit a native build to a store without an external worker.
BEGIN;

CREATE TABLE IF NOT EXISTS public.studio_release_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    kind TEXT NOT NULL CHECK (kind IN ('web_deploy', 'mobile_build')),
    platform TEXT CHECK (platform IN ('android', 'ios')),
    config_version INTEGER NOT NULL CHECK (config_version > 0),
    status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'running', 'succeeded', 'failed')),
    store_release_status TEXT NOT NULL DEFAULT 'not_submitted' CHECK (store_release_status IN ('not_submitted', 'pending', 'released', 'rejected')),
    failure_reason TEXT,
    requested_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    requested_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CHECK ((kind = 'web_deploy' AND platform IS NULL) OR (kind = 'mobile_build' AND platform IS NOT NULL)),
    CHECK ((status <> 'failed') OR failure_reason IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS idx_studio_release_jobs_tenant_history ON public.studio_release_jobs (chef_id, requested_at DESC);
ALTER TABLE public.studio_release_jobs ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.studio_audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    subject_type TEXT NOT NULL,
    subject_id UUID,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_studio_audit_log_tenant_created ON public.studio_audit_log (chef_id, created_at DESC);
ALTER TABLE public.studio_audit_log ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.publish_studio_brand_draft(p_chef_id UUID, p_user_id UUID, p_expected_version INTEGER)
RETURNS TABLE(version INTEGER, published_at TIMESTAMP WITH TIME ZONE)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_config JSONB; v_version INTEGER; v_now TIMESTAMP WITH TIME ZONE := NOW();
BEGIN
    SELECT config INTO v_config FROM studio_brand_drafts WHERE chef_id = p_chef_id AND version = p_expected_version FOR UPDATE;
    IF v_config IS NULL THEN RETURN; END IF;
    UPDATE brand_configs SET status = 'archived' WHERE chef_id = p_chef_id AND status = 'published';
    SELECT COALESCE(MAX(version), 0) + 1 INTO v_version FROM brand_configs WHERE chef_id = p_chef_id;
    INSERT INTO brand_configs (chef_id, version, status, config, created_by, published_at) VALUES (p_chef_id, v_version, 'published', v_config, p_user_id, v_now);
    INSERT INTO studio_audit_log (chef_id, actor_id, action, subject_type, metadata) VALUES (p_chef_id, p_user_id, 'config_published', 'brand_config', jsonb_build_object('version', v_version, 'draftVersion', p_expected_version));
    RETURN QUERY SELECT v_version, v_now;
END; $$;

CREATE OR REPLACE FUNCTION public.rollback_studio_brand_config(p_chef_id UUID, p_user_id UUID, p_source_version INTEGER)
RETURNS TABLE(version INTEGER, published_at TIMESTAMP WITH TIME ZONE)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_config JSONB; v_version INTEGER; v_now TIMESTAMP WITH TIME ZONE := NOW();
BEGIN
    SELECT config INTO v_config FROM brand_configs WHERE chef_id = p_chef_id AND version = p_source_version;
    IF v_config IS NULL THEN RETURN; END IF;
    UPDATE brand_configs SET status = 'archived' WHERE chef_id = p_chef_id AND status = 'published';
    SELECT COALESCE(MAX(version), 0) + 1 INTO v_version FROM brand_configs WHERE chef_id = p_chef_id;
    INSERT INTO brand_configs (chef_id, version, status, config, created_by, published_at) VALUES (p_chef_id, v_version, 'published', v_config, p_user_id, v_now);
    INSERT INTO studio_audit_log (chef_id, actor_id, action, subject_type, metadata) VALUES (p_chef_id, p_user_id, 'config_rolled_back', 'brand_config', jsonb_build_object('version', v_version, 'sourceVersion', p_source_version));
    RETURN QUERY SELECT v_version, v_now;
END; $$;

CREATE OR REPLACE FUNCTION public.create_studio_release_job(p_chef_id UUID, p_user_id UUID, p_kind TEXT, p_platform TEXT, p_config_version INTEGER)
RETURNS SETOF studio_release_jobs LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_job studio_release_jobs;
BEGIN
    INSERT INTO studio_release_jobs (chef_id, kind, platform, config_version, requested_by)
    VALUES (p_chef_id, p_kind, p_platform, p_config_version, p_user_id) RETURNING * INTO v_job;
    INSERT INTO studio_audit_log (chef_id, actor_id, action, subject_type, subject_id, metadata) VALUES (p_chef_id, p_user_id, 'release_requested', 'release_job', v_job.id, jsonb_build_object('kind', p_kind, 'platform', p_platform, 'configVersion', p_config_version));
    RETURN NEXT v_job;
END; $$;

CREATE OR REPLACE FUNCTION public.update_studio_release_job(p_release_id UUID, p_chef_id UUID, p_user_id UUID, p_status TEXT, p_store_release_status TEXT, p_failure_reason TEXT)
RETURNS SETOF studio_release_jobs LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_job studio_release_jobs;
BEGIN
    UPDATE studio_release_jobs SET status = p_status, store_release_status = COALESCE(p_store_release_status, store_release_status), failure_reason = CASE WHEN p_status = 'failed' THEN p_failure_reason ELSE NULL END, updated_at = NOW()
    WHERE id = p_release_id AND chef_id = p_chef_id RETURNING * INTO v_job;
    IF NOT FOUND THEN RETURN; END IF;
    INSERT INTO studio_audit_log (chef_id, actor_id, action, subject_type, subject_id, metadata) VALUES (p_chef_id, p_user_id, 'release_status_updated', 'release_job', v_job.id, jsonb_build_object('status', v_job.status, 'storeReleaseStatus', v_job.store_release_status));
    RETURN NEXT v_job;
END; $$;

REVOKE ALL ON FUNCTION public.publish_studio_brand_draft(UUID, UUID, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rollback_studio_brand_config(UUID, UUID, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_studio_release_job(UUID, UUID, TEXT, TEXT, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.update_studio_release_job(UUID, UUID, UUID, TEXT, TEXT, TEXT) FROM PUBLIC;
COMMIT;
