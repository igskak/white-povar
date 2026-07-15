-- COL-02: tenant-scoped published collections with reusable ordered content.
BEGIN;

CREATE TABLE IF NOT EXISTS public.collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    slug TEXT NOT NULL,
    title_i18n JSONB NOT NULL,
    description_i18n JSONB NOT NULL DEFAULT '{}'::jsonb,
    cover_url TEXT,
    is_premium BOOLEAN NOT NULL DEFAULT FALSE,
    status TEXT NOT NULL DEFAULT 'draft',
    published_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT collections_status_check CHECK (status IN ('draft', 'published', 'archived')),
    CONSTRAINT collections_published_at_check CHECK (status <> 'published' OR published_at IS NOT NULL),
    CONSTRAINT collections_slug_per_tenant_unique UNIQUE (chef_id, slug),
    CONSTRAINT collections_title_i18n_not_empty CHECK (jsonb_typeof(title_i18n) = 'object' AND title_i18n ? 'uk'),
    CONSTRAINT collections_description_i18n_object CHECK (jsonb_typeof(description_i18n) = 'object')
);

CREATE TABLE IF NOT EXISTS public.collection_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    collection_id UUID NOT NULL REFERENCES public.collections(id) ON DELETE CASCADE,
    recipe_id UUID NOT NULL REFERENCES public.recipes(id) ON DELETE RESTRICT,
    position INTEGER NOT NULL CHECK (position >= 0),
    is_preview BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT collection_items_position_unique UNIQUE (collection_id, position),
    CONSTRAINT collection_items_recipe_unique UNIQUE (collection_id, recipe_id)
);

CREATE INDEX IF NOT EXISTS collections_consumer_listing_idx
    ON public.collections (chef_id, published_at DESC, id) WHERE status = 'published';
CREATE INDEX IF NOT EXISTS collection_items_order_idx
    ON public.collection_items (collection_id, position, id);

-- A service-role write must not be able to attach another tenant's content.
CREATE OR REPLACE FUNCTION public.enforce_collection_item_tenant()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    collection_chef_id UUID;
    content_chef_id UUID;
BEGIN
    SELECT chef_id INTO collection_chef_id FROM public.collections WHERE id = NEW.collection_id;
    SELECT chef_id INTO content_chef_id FROM public.recipes WHERE id = NEW.recipe_id;
    IF collection_chef_id IS NULL OR content_chef_id IS NULL OR collection_chef_id <> content_chef_id THEN
        RAISE EXCEPTION 'Collection item content must belong to the collection tenant';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS collection_items_enforce_tenant ON public.collection_items;
CREATE TRIGGER collection_items_enforce_tenant
    BEFORE INSERT OR UPDATE OF collection_id, recipe_id ON public.collection_items
    FOR EACH ROW EXECUTE FUNCTION public.enforce_collection_item_tenant();

ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collection_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS wp_collections_select_published ON public.collections;
CREATE POLICY wp_collections_select_published ON public.collections FOR SELECT TO anon, authenticated
    USING (status = 'published');
DROP POLICY IF EXISTS wp_collection_items_select_published ON public.collection_items;
CREATE POLICY wp_collection_items_select_published ON public.collection_items FOR SELECT TO anon, authenticated
    USING (EXISTS (SELECT 1 FROM public.collections c WHERE c.id = collection_items.collection_id AND c.status = 'published'));

COMMIT;
