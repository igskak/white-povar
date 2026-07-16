-- DEMO-01: server-owned web demo offers and transactional demo entitlements.
BEGIN;

ALTER TABLE public.offers
    ADD COLUMN IF NOT EXISTS title TEXT,
    ADD COLUMN IF NOT EXISTS description TEXT,
    ADD COLUMN IF NOT EXISTS amount_minor INTEGER,
    ADD COLUMN IF NOT EXISTS currency TEXT,
    ADD COLUMN IF NOT EXISTS billing_period TEXT,
    ADD COLUMN IF NOT EXISTS badge TEXT,
    ADD COLUMN IF NOT EXISTS trial_days INTEGER;

ALTER TABLE public.offers
    DROP CONSTRAINT IF EXISTS offers_amount_minor_check,
    ADD CONSTRAINT offers_amount_minor_check CHECK (amount_minor IS NULL OR amount_minor >= 0),
    DROP CONSTRAINT IF EXISTS offers_currency_check,
    ADD CONSTRAINT offers_currency_check CHECK (currency IS NULL OR currency ~ '^[A-Z]{3}$'),
    DROP CONSTRAINT IF EXISTS offers_billing_period_check,
    ADD CONSTRAINT offers_billing_period_check CHECK (billing_period IS NULL OR billing_period IN ('month', 'year', 'one_off')),
    DROP CONSTRAINT IF EXISTS offers_trial_days_check,
    ADD CONSTRAINT offers_trial_days_check CHECK (trial_days IS NULL OR trial_days >= 0);

ALTER TABLE public.commerce_entitlements
    DROP CONSTRAINT IF EXISTS commerce_entitlements_source_check,
    ADD CONSTRAINT commerce_entitlements_source_check CHECK (source IN ('migration', 'store', 'admin', 'demo'));

-- The server resolves every sensitive value from the tenant offer.  The only
-- caller-provided purchase field is an opaque idempotency key.
CREATE OR REPLACE FUNCTION public.issue_demo_purchase(
    p_user_id UUID,
    p_chef_id UUID,
    p_offer_key TEXT,
    p_idempotency_key TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_offer public.offers%ROWTYPE;
    v_product public.products%ROWTYPE;
    v_collection_id UUID;
    v_event public.purchase_events%ROWTYPE;
    v_entitlement public.commerce_entitlements%ROWTYPE;
    v_event_key TEXT := p_chef_id::text || ':' || p_user_id::text || ':' || p_idempotency_key;
BEGIN
    IF p_offer_key IS NULL OR btrim(p_offer_key) = '' OR p_idempotency_key IS NULL OR btrim(p_idempotency_key) = '' THEN
        RAISE EXCEPTION 'offer key and idempotency key are required' USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_event FROM public.purchase_events
    WHERE provider = 'demo' AND event_key = v_event_key FOR UPDATE;
    IF FOUND THEN
        SELECT * INTO v_entitlement FROM public.commerce_entitlements WHERE id = v_event.entitlement_id;
        RETURN jsonb_build_object('accepted', v_entitlement.id IS NOT NULL, 'eventId', v_event.id,
            'entitlementId', v_entitlement.id, 'status', v_entitlement.status,
            'expiresAt', v_entitlement.expires_at, 'scopeType', v_entitlement.scope_type,
            'collectionId', v_entitlement.collection_id);
    END IF;

    SELECT * INTO v_offer FROM public.offers
    WHERE chef_id = p_chef_id AND offer_key = p_offer_key AND status = 'active' FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('accepted', false);
    END IF;
    SELECT * INTO v_product FROM public.products WHERE id = v_offer.product_id AND chef_id = p_chef_id AND status = 'active';
    IF NOT FOUND THEN
        RETURN jsonb_build_object('accepted', false);
    END IF;
    IF v_product.kind = 'one_off' THEN
        SELECT collection_id INTO v_collection_id FROM public.product_content
        WHERE product_id = v_product.id AND chef_id = p_chef_id ORDER BY collection_id LIMIT 1;
        IF v_collection_id IS NULL THEN
            RETURN jsonb_build_object('accepted', false);
        END IF;
    END IF;

    INSERT INTO public.purchase_events(provider, event_key, event_type, occurred_at, processing_status, payload)
    VALUES ('demo', v_event_key, 'demo_purchase', now(), 'received',
            jsonb_build_object('offer_key', v_offer.offer_key, 'product_kind', v_product.kind))
    RETURNING * INTO v_event;
    INSERT INTO public.commerce_entitlements(user_id, chef_id, product_id, scope_type, collection_id, source, status, starts_at, expires_at, source_reference)
    VALUES (p_user_id, p_chef_id, v_product.id,
            CASE WHEN v_product.kind = 'subscription' THEN 'tenant' ELSE 'collection' END,
            v_collection_id, 'demo', 'active', now(),
            CASE WHEN v_product.kind = 'subscription' THEN now() + interval '30 days' ELSE NULL END,
            'demo-event:' || v_event.id::text)
    RETURNING * INTO v_entitlement;
    UPDATE public.purchase_events SET processing_status = 'processed', processed_at = now(), entitlement_id = v_entitlement.id WHERE id = v_event.id;
    RETURN jsonb_build_object('accepted', true, 'eventId', v_event.id, 'entitlementId', v_entitlement.id,
        'status', v_entitlement.status, 'expiresAt', v_entitlement.expires_at,
        'scopeType', v_entitlement.scope_type, 'collectionId', v_entitlement.collection_id);
END;
$$;
REVOKE ALL ON FUNCTION public.issue_demo_purchase(UUID, UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.issue_demo_purchase(UUID, UUID, TEXT, TEXT) TO service_role;

-- Seed offers only for the pilot tenant. The one-off stays absent until a
-- premium collection exists, so it can never point across tenants.
WITH tenant AS (SELECT id FROM public.chefs WHERE slug = 'ohorodnik-oleksandr')
INSERT INTO public.products(chef_id, product_key, kind, status)
SELECT id, key, 'subscription', 'active' FROM tenant CROSS JOIN (VALUES ('demo-monthly'), ('demo-annual')) AS v(key)
ON CONFLICT (chef_id, product_key) DO UPDATE SET status = 'active', updated_at = now();

WITH tenant AS (SELECT id FROM public.chefs WHERE slug = 'ohorodnik-oleksandr')
INSERT INTO public.offers(chef_id, product_id, offer_key, status, title, description, amount_minor, currency, billing_period, badge, trial_days)
SELECT tenant.id, product.id, values_.offer_key, 'active', values_.title, values_.description, values_.amount_minor, 'EUR', values_.billing_period, values_.badge, 0
FROM tenant
CROSS JOIN (VALUES
    ('demo-monthly', 'demo-monthly', 'Щомісячний доступ', 'Демо-доступ до всіх premium матеріалів.', 999, 'month', NULL),
    ('demo-annual', 'demo-annual', 'Річний доступ', 'Демо-доступ до всіх premium матеріалів.', 9999, 'year', 'Вигідно')
) AS values_(offer_key, product_key, title, description, amount_minor, billing_period, badge)
JOIN public.products product ON product.chef_id = tenant.id AND product.product_key = values_.product_key
ON CONFLICT (chef_id, offer_key) DO UPDATE SET status = EXCLUDED.status, title = EXCLUDED.title, description = EXCLUDED.description,
    amount_minor = EXCLUDED.amount_minor, currency = EXCLUDED.currency, billing_period = EXCLUDED.billing_period, badge = EXCLUDED.badge, updated_at = now();

WITH tenant AS (SELECT id FROM public.chefs WHERE slug = 'ohorodnik-oleksandr'),
premium_collection AS (
    SELECT collections.id, collections.chef_id FROM public.collections JOIN tenant ON tenant.id = collections.chef_id
    WHERE collections.is_premium = true ORDER BY collections.published_at NULLS LAST, collections.id LIMIT 1
), product AS (
    INSERT INTO public.products(chef_id, product_key, kind, status)
    SELECT chef_id, 'demo-premium-collection', 'one_off', 'active' FROM premium_collection
    ON CONFLICT (chef_id, product_key) DO UPDATE SET status = 'active', updated_at = now()
    RETURNING id, chef_id
)
INSERT INTO public.product_content(product_id, chef_id, collection_id)
SELECT product.id, product.chef_id, premium_collection.id FROM product JOIN premium_collection ON premium_collection.chef_id = product.chef_id
ON CONFLICT (product_id, collection_id) DO NOTHING;

WITH tenant AS (SELECT id FROM public.chefs WHERE slug = 'ohorodnik-oleksandr')
INSERT INTO public.offers(chef_id, product_id, offer_key, status, title, description, amount_minor, currency, billing_period, badge, trial_days)
SELECT tenant.id, product.id, 'demo-premium-collection', 'active', 'Майстерня Олександра',
       'Разовий демо-доступ до premium колекції.', 2499, 'EUR', 'one_off', NULL, 0
FROM tenant JOIN public.products product ON product.chef_id = tenant.id AND product.product_key = 'demo-premium-collection'
ON CONFLICT (chef_id, offer_key) DO UPDATE SET status = EXCLUDED.status, title = EXCLUDED.title, description = EXCLUDED.description,
    amount_minor = EXCLUDED.amount_minor, currency = EXCLUDED.currency, billing_period = EXCLUDED.billing_period, updated_at = now();

COMMIT;
