-- COM-01: server-side commerce catalogue, entitlement scopes and event ledger.
-- Prices and store product identifiers deliberately do not live here. COM-02
-- owns store integration and COM-03 owns the consumer purchase flow.
BEGIN;

CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    product_key TEXT NOT NULL,
    kind TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT products_kind_check CHECK (kind IN ('subscription', 'one_off')),
    CONSTRAINT products_status_check CHECK (status IN ('draft', 'active', 'archived')),
    CONSTRAINT products_key_per_tenant_unique UNIQUE (chef_id, product_key)
);

CREATE TABLE IF NOT EXISTS public.offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    offer_key TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT offers_status_check CHECK (status IN ('draft', 'active', 'archived')),
    CONSTRAINT offers_key_per_tenant_unique UNIQUE (chef_id, offer_key)
);

-- A subscription has tenant scope. A one-off product is explicitly mapped to
-- one or more collections; it never grants a different collection by inference.
CREATE TABLE IF NOT EXISTS public.product_content (
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    collection_id UUID NOT NULL REFERENCES public.collections(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    PRIMARY KEY (product_id, collection_id)
);

CREATE TABLE IF NOT EXISTS public.commerce_entitlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    scope_type TEXT NOT NULL,
    collection_id UUID REFERENCES public.collections(id) ON DELETE CASCADE,
    source TEXT NOT NULL,
    status TEXT NOT NULL,
    starts_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    expires_at TIMESTAMP WITH TIME ZONE,
    source_reference TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT commerce_entitlements_scope_check CHECK (
        (scope_type = 'tenant' AND collection_id IS NULL)
        OR (scope_type = 'collection' AND collection_id IS NOT NULL)
    ),
    CONSTRAINT commerce_entitlements_source_check CHECK (source IN ('migration', 'store', 'admin')),
    CONSTRAINT commerce_entitlements_status_check CHECK (
        status IN ('active', 'trial', 'grace', 'expired', 'refunded', 'revoked')
    ),
    CONSTRAINT commerce_entitlements_source_reference_unique UNIQUE NULLS NOT DISTINCT (source, source_reference)
);

CREATE TABLE IF NOT EXISTS public.purchase_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider TEXT NOT NULL,
    event_key TEXT NOT NULL,
    event_type TEXT NOT NULL,
    occurred_at TIMESTAMP WITH TIME ZONE,
    received_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    processed_at TIMESTAMP WITH TIME ZONE,
    processing_status TEXT NOT NULL DEFAULT 'received',
    entitlement_id UUID REFERENCES public.commerce_entitlements(id) ON DELETE SET NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT purchase_events_status_check CHECK (processing_status IN ('received', 'processed', 'rejected')),
    CONSTRAINT purchase_events_provider_key_unique UNIQUE (provider, event_key)
);

CREATE INDEX IF NOT EXISTS commerce_entitlements_access_idx
    ON public.commerce_entitlements (user_id, chef_id, status, expires_at);
CREATE INDEX IF NOT EXISTS product_content_collection_idx
    ON public.product_content (chef_id, collection_id, product_id);

CREATE OR REPLACE FUNCTION public.enforce_commerce_tenant_scope()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    product_chef_id UUID;
    collection_chef_id UUID;
BEGIN
    IF TG_TABLE_NAME = 'offers' THEN
        SELECT chef_id INTO product_chef_id FROM public.products WHERE id = NEW.product_id;
        IF product_chef_id IS NULL OR product_chef_id <> NEW.chef_id THEN
            RAISE EXCEPTION 'Offer product must belong to the offer tenant';
        END IF;
    ELSIF TG_TABLE_NAME = 'product_content' THEN
        SELECT chef_id INTO product_chef_id FROM public.products WHERE id = NEW.product_id;
        SELECT chef_id INTO collection_chef_id FROM public.collections WHERE id = NEW.collection_id;
        IF product_chef_id IS NULL OR collection_chef_id IS NULL
           OR product_chef_id <> NEW.chef_id OR collection_chef_id <> NEW.chef_id THEN
            RAISE EXCEPTION 'Product content must belong to the product tenant';
        END IF;
    ELSIF TG_TABLE_NAME = 'commerce_entitlements' THEN
        SELECT chef_id INTO product_chef_id FROM public.products WHERE id = NEW.product_id;
        IF product_chef_id IS NULL OR product_chef_id <> NEW.chef_id THEN
            RAISE EXCEPTION 'Entitlement product must belong to the entitlement tenant';
        END IF;
        IF NEW.collection_id IS NOT NULL THEN
            SELECT chef_id INTO collection_chef_id FROM public.collections WHERE id = NEW.collection_id;
            IF collection_chef_id IS NULL OR collection_chef_id <> NEW.chef_id THEN
                RAISE EXCEPTION 'Entitlement collection must belong to the entitlement tenant';
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS offers_enforce_commerce_tenant ON public.offers;
CREATE TRIGGER offers_enforce_commerce_tenant BEFORE INSERT OR UPDATE ON public.offers
    FOR EACH ROW EXECUTE FUNCTION public.enforce_commerce_tenant_scope();
DROP TRIGGER IF EXISTS product_content_enforce_commerce_tenant ON public.product_content;
CREATE TRIGGER product_content_enforce_commerce_tenant BEFORE INSERT OR UPDATE ON public.product_content
    FOR EACH ROW EXECUTE FUNCTION public.enforce_commerce_tenant_scope();
DROP TRIGGER IF EXISTS commerce_entitlements_enforce_commerce_tenant ON public.commerce_entitlements;
CREATE TRIGGER commerce_entitlements_enforce_commerce_tenant BEFORE INSERT OR UPDATE ON public.commerce_entitlements
    FOR EACH ROW EXECUTE FUNCTION public.enforce_commerce_tenant_scope();

-- Preserve access granted before COM-01 without retaining two decision paths.
INSERT INTO public.products (chef_id, product_key, kind, status)
SELECT DISTINCT chef_id, 'legacy-' || product_id, 'subscription', 'active'
FROM public.tenant_entitlements
ON CONFLICT (chef_id, product_key) DO NOTHING;

INSERT INTO public.commerce_entitlements (
    user_id, chef_id, product_id, scope_type, source, status, starts_at, expires_at, source_reference
)
SELECT legacy.user_id, legacy.chef_id, product.id, 'tenant', 'migration',
       CASE WHEN legacy.is_active THEN 'active' ELSE 'revoked' END,
       legacy.granted_at, legacy.expires_at,
       'tenant-entitlement:' || legacy.user_id || ':' || legacy.chef_id || ':' || legacy.product_id
FROM public.tenant_entitlements legacy
JOIN public.products product
  ON product.chef_id = legacy.chef_id AND product.product_key = 'legacy-' || legacy.product_id
ON CONFLICT (source, source_reference) DO NOTHING;

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commerce_entitlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS wp_commerce_entitlements_select_own ON public.commerce_entitlements;
CREATE POLICY wp_commerce_entitlements_select_own ON public.commerce_entitlements
    FOR SELECT TO authenticated USING (user_id = auth.uid());

COMMIT;
