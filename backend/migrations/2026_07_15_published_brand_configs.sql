-- Forward-only migration: tenant slugs and versioned runtime configuration.
-- BrandConfig and product config remain separate so runtime branding cannot
-- accidentally acquire pricing, feature-flag, or legal-link responsibilities.

BEGIN;

ALTER TABLE public.chefs
    ADD COLUMN IF NOT EXISTS slug TEXT;

-- Existing chefs predate tenant slugs. UUID-derived values are deterministic,
-- unique, and safe until an administrator assigns a human-readable slug.
UPDATE public.chefs
SET slug = 'chef-' || id::text
WHERE slug IS NULL;

ALTER TABLE public.chefs
    ALTER COLUMN slug SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_chefs_slug_unique
    ON public.chefs (slug);

CREATE TABLE IF NOT EXISTS public.brand_configs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    version INTEGER NOT NULL CHECK (version > 0),
    status TEXT NOT NULL CHECK (status IN ('draft', 'published', 'archived')),
    config JSONB NOT NULL,
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    published_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT brand_configs_chef_version_unique UNIQUE (chef_id, version),
    CONSTRAINT brand_configs_published_at CHECK (
        (status = 'published' AND published_at IS NOT NULL)
        OR status <> 'published'
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS brand_configs_one_published_per_chef
    ON public.brand_configs (chef_id)
    WHERE status = 'published';

CREATE INDEX IF NOT EXISTS idx_brand_configs_published_lookup
    ON public.brand_configs (chef_id, version DESC)
    WHERE status = 'published';

ALTER TABLE public.brand_configs ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.product_configs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    version INTEGER NOT NULL CHECK (version > 0),
    status TEXT NOT NULL CHECK (status IN ('draft', 'published', 'archived')),
    config JSONB NOT NULL,
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    published_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT product_configs_chef_version_unique UNIQUE (chef_id, version),
    CONSTRAINT product_configs_published_at CHECK (
        (status = 'published' AND published_at IS NOT NULL)
        OR status <> 'published'
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS product_configs_one_published_per_chef
    ON public.product_configs (chef_id)
    WHERE status = 'published';

CREATE INDEX IF NOT EXISTS idx_product_configs_published_lookup
    ON public.product_configs (chef_id, version DESC)
    WHERE status = 'published';

ALTER TABLE public.product_configs ENABLE ROW LEVEL SECURITY;

COMMIT;
