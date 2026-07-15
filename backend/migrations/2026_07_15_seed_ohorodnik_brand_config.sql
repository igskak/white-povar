-- Optional pilot seed. Run after 2026_07_15_published_brand_configs.sql.
-- The JSON matches backend/tests/fixtures/ohorodnik-oleksandr.brand-config.json;
-- its derived tokens are intentionally stored, never calculated by clients.

BEGIN;

INSERT INTO public.chefs (id, slug, name, avatar_url, is_active)
VALUES (
    'f67e6e9d-f905-48a0-b0be-a64bd0c649f2',
    'ohorodnik-oleksandr',
    'Огороднік Олександр',
    'PENDING:/brands/ohorodnik-oleksandr/avatar-512.png',
    TRUE
)
ON CONFLICT (slug) DO UPDATE
SET name = EXCLUDED.name,
    avatar_url = EXCLUDED.avatar_url,
    is_active = TRUE;

INSERT INTO public.brand_configs (chef_id, version, status, config, published_at)
SELECT id, 1, 'published',
    '{
      "schemaVersion": 1,
      "tenantSlug": "ohorodnik-oleksandr",
      "locale": "uk",
      "brand": {
        "name": "Огороднік Олександр",
        "creatorName": "Олександр",
        "avatar": "PENDING:/brands/ohorodnik-oleksandr/avatar-512.png",
        "accent": "#5D7183",
        "font": "grotesque",
        "voice": {
          "greeting": "Ой, друзі, ну це щось...",
          "loginTitle": "Готуйте з Олександром",
          "paywallTitle": "Колекції Олександра",
          "courseName": "Майстерня Олександра"
        },
        "courseTag": "maisternia-oleksandra",
        "heroPhotos": [],
        "logo": null,
        "derived": {
          "accentPressed": "#4B5E70",
          "accentOnDark": "#6B8092",
          "onAccent": "#FFFFFF",
          "lightCtaMode": "accentFill"
        }
      }
    }'::jsonb,
    NOW()
FROM public.chefs
WHERE slug = 'ohorodnik-oleksandr'
ON CONFLICT (chef_id, version) DO NOTHING;

-- Product config remains separate from BrandConfig by architecture contract.
INSERT INTO public.product_configs (chef_id, version, status, config, published_at)
SELECT id, 1, 'published', '{"locale":"uk","features":{}}'::jsonb, NOW()
FROM public.chefs
WHERE slug = 'ohorodnik-oleksandr'
ON CONFLICT (chef_id, version) DO NOTHING;

COMMIT;
