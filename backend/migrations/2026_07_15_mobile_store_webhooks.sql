-- COM-02: RevenueCat is the managed verifier for StoreKit and Play Billing.
-- Store IDs live server-side; native SDKs receive only their tenant-scoped IDs.
BEGIN;

CREATE TABLE IF NOT EXISTS public.store_product_mappings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    provider TEXT NOT NULL DEFAULT 'revenuecat',
    store TEXT NOT NULL,
    store_product_id TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT store_product_mapping_provider_check CHECK (provider = 'revenuecat'),
    CONSTRAINT store_product_mapping_store_check CHECK (store IN ('app_store', 'play_store')),
    CONSTRAINT store_product_mapping_status_check CHECK (status IN ('active', 'archived')),
    CONSTRAINT store_product_mapping_tenant_product_unique UNIQUE (chef_id, product_id, provider, store),
    CONSTRAINT store_product_mapping_store_id_unique UNIQUE (provider, store, store_product_id)
);

CREATE INDEX IF NOT EXISTS store_product_mappings_catalog_idx
    ON public.store_product_mappings (chef_id, provider, store, status);

CREATE OR REPLACE FUNCTION public.enforce_store_product_mapping_tenant()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE product_chef_id UUID;
BEGIN
    SELECT chef_id INTO product_chef_id FROM public.products WHERE id = NEW.product_id;
    IF product_chef_id IS NULL OR product_chef_id <> NEW.chef_id THEN
        RAISE EXCEPTION 'Store product mapping must belong to the product tenant';
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS store_product_mappings_enforce_tenant ON public.store_product_mappings;
CREATE TRIGGER store_product_mappings_enforce_tenant BEFORE INSERT OR UPDATE ON public.store_product_mappings
    FOR EACH ROW EXECUTE FUNCTION public.enforce_store_product_mapping_tenant();

CREATE OR REPLACE FUNCTION public.process_revenuecat_event(event_payload JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    rc_event JSONB := event_payload;
    rc_event_id TEXT := rc_event->>'id';
    rc_type TEXT := rc_event->>'type';
    rc_user_id UUID := (rc_event->>'app_user_id')::UUID;
    rc_product_id TEXT := rc_event->>'product_id';
    rc_store TEXT := CASE lower(coalesce(rc_event->>'store', ''))
        WHEN 'app_store' THEN 'app_store' WHEN 'play_store' THEN 'play_store'
        WHEN 'appstore' THEN 'app_store' WHEN 'playstore' THEN 'play_store' END;
    rc_occurred_at TIMESTAMPTZ := to_timestamp((rc_event->>'event_timestamp_ms')::NUMERIC / 1000.0);
    rc_expires_at TIMESTAMPTZ := CASE WHEN nullif(rc_event->>'expiration_at_ms', '') IS NULL THEN NULL
        ELSE to_timestamp((rc_event->>'expiration_at_ms')::NUMERIC / 1000.0) END;
    mapping public.store_product_mappings%ROWTYPE;
    entitlement public.commerce_entitlements%ROWTYPE;
    next_status TEXT;
    reference TEXT := 'revenuecat:' || coalesce(rc_event->>'original_transaction_id', rc_event_id) || ':' || rc_product_id;
BEGIN
    INSERT INTO public.purchase_events(provider, event_key, event_type, occurred_at, payload)
    VALUES ('revenuecat', rc_event_id, rc_type, rc_occurred_at, rc_event)
    ON CONFLICT (provider, event_key) DO NOTHING;
    IF NOT FOUND THEN RETURN jsonb_build_object('accepted', true, 'duplicate', true); END IF;

    SELECT mapping.* INTO mapping FROM public.store_product_mappings mapping
      JOIN public.products product ON product.id = mapping.product_id
      WHERE mapping.provider = 'revenuecat' AND mapping.store = rc_store
        AND mapping.store_product_id = rc_product_id AND mapping.status = 'active'
        AND product.kind = 'subscription';
    IF NOT FOUND THEN
      UPDATE public.purchase_events SET processing_status = 'rejected', processed_at = now()
       WHERE provider = 'revenuecat' AND event_key = rc_event_id;
      RETURN jsonb_build_object('accepted', true, 'ignored', 'unmapped_product');
    END IF;
    IF rc_type IN ('REFUND', 'TRANSFER') THEN next_status := 'refunded';
    ELSIF rc_type = 'EXPIRATION' THEN next_status := 'expired';
    ELSIF rc_type = 'BILLING_ISSUE' THEN next_status := 'grace';
    ELSE next_status := 'active'; END IF;

    SELECT * INTO entitlement FROM public.commerce_entitlements
     WHERE source = 'store' AND source_reference = reference FOR UPDATE;
    IF FOUND AND entitlement.updated_at > rc_occurred_at THEN
      UPDATE public.purchase_events SET processing_status = 'processed', entitlement_id = entitlement.id, processed_at = now()
       WHERE provider = 'revenuecat' AND event_key = rc_event_id;
      RETURN jsonb_build_object('accepted', true, 'outOfOrder', true);
    END IF;
    INSERT INTO public.commerce_entitlements(user_id, chef_id, product_id, scope_type, source, status, starts_at, expires_at, source_reference, updated_at)
    VALUES (rc_user_id, mapping.chef_id, mapping.product_id, 'tenant', 'store', next_status,
            coalesce(rc_occurred_at, now()), rc_expires_at, reference, coalesce(rc_occurred_at, now()))
    ON CONFLICT (source, source_reference) DO UPDATE SET status = EXCLUDED.status,
      expires_at = EXCLUDED.expires_at, updated_at = EXCLUDED.updated_at
    RETURNING * INTO entitlement;
    UPDATE public.purchase_events SET processing_status = 'processed', entitlement_id = entitlement.id, processed_at = now()
     WHERE provider = 'revenuecat' AND event_key = rc_event_id;
    RETURN jsonb_build_object('accepted', true, 'entitlementId', entitlement.id);
END;
$$;

ALTER TABLE public.store_product_mappings ENABLE ROW LEVEL SECURITY;
COMMIT;
