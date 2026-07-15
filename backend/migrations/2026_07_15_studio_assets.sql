-- STUDIO-02: tenant-bound brand assets. Files enter a staging prefix and are
-- publicly addressable only after server validation and compression.
BEGIN;
CREATE TABLE IF NOT EXISTS public.studio_assets (
 id UUID PRIMARY KEY, chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
 created_by UUID REFERENCES public.users(id) ON DELETE SET NULL, source_path TEXT NOT NULL UNIQUE,
 object_path TEXT, content_type TEXT NOT NULL CHECK (content_type IN ('image/jpeg','image/png','image/webp')),
 size_bytes BIGINT NOT NULL CHECK (size_bytes > 0 AND size_bytes <= 12582912), width INTEGER CHECK (width > 0), height INTEGER CHECK (height > 0),
    alt_text TEXT, url TEXT, state TEXT NOT NULL CHECK (state IN ('uploading','ready','rejected')), rejection_reason TEXT,
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(), finalized_at TIMESTAMP WITH TIME ZONE);
CREATE INDEX IF NOT EXISTS idx_studio_assets_chef_state ON public.studio_assets (chef_id, state);
ALTER TABLE public.studio_assets ENABLE ROW LEVEL SECURITY;
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('studio-brand-assets','studio-brand-assets',true,12582912,ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT (id) DO UPDATE SET public=true, file_size_limit=12582912, allowed_mime_types=ARRAY['image/jpeg','image/png','image/webp'];
CREATE OR REPLACE FUNCTION public.purge_expired_studio_asset_uploads() RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, storage AS $$
DECLARE v_count INTEGER; BEGIN
 WITH expired AS (DELETE FROM public.studio_assets WHERE state='uploading' AND created_at < NOW() - INTERVAL '24 hours' RETURNING source_path)
 DELETE FROM storage.objects o USING expired e WHERE o.bucket_id='studio-brand-assets' AND o.name=e.source_path;
 GET DIAGNOSTICS v_count = ROW_COUNT; RETURN v_count;
END; $$;
REVOKE ALL ON FUNCTION public.purge_expired_studio_asset_uploads() FROM PUBLIC;
COMMIT;
