-- DB-02 corrective seed: the initial demo-commerce migration can run before
-- the optional pilot tenant seed, so rerun only its idempotent offer seed after
-- BrandConfig has guaranteed the tenant exists. No entitlement is created.
BEGIN;

WITH tenant AS (SELECT id FROM public.chefs WHERE slug = 'ohorodnik-oleksandr')
INSERT INTO public.products(chef_id, product_key, kind, status)
SELECT id, key, 'subscription', 'active'
FROM tenant CROSS JOIN (VALUES ('demo-monthly'), ('demo-annual')) AS v(key)
ON CONFLICT (chef_id, product_key) DO UPDATE SET status = 'active', updated_at = now();

WITH tenant AS (SELECT id FROM public.chefs WHERE slug = 'ohorodnik-oleksandr')
INSERT INTO public.offers(chef_id, product_id, offer_key, status, title, description, amount_minor, currency, billing_period, badge, trial_days)
SELECT tenant.id, product.id, values_.offer_key, 'active', values_.title, values_.description,
       values_.amount_minor, 'EUR', values_.billing_period, values_.badge, 0
FROM tenant
CROSS JOIN (VALUES
    ('demo-monthly', 'demo-monthly', 'Щомісячний доступ', 'Демо-доступ до всіх premium матеріалів.', 999, 'month', NULL),
    ('demo-annual', 'demo-annual', 'Річний доступ', 'Демо-доступ до всіх premium матеріалів.', 9999, 'year', 'Вигідно')
) AS values_(offer_key, product_key, title, description, amount_minor, billing_period, badge)
JOIN public.products product ON product.chef_id = tenant.id AND product.product_key = values_.product_key
ON CONFLICT (chef_id, offer_key) DO UPDATE SET
    status = EXCLUDED.status,
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    amount_minor = EXCLUDED.amount_minor,
    currency = EXCLUDED.currency,
    billing_period = EXCLUDED.billing_period,
    badge = EXCLUDED.badge,
    updated_at = now();

COMMIT;
