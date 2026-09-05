-- Publish the Bordeaux editorial identity without overwriting the tenant's
-- current logo, photography, course settings or authentication copy.
BEGIN;

DO $$
DECLARE
    v_chef_id UUID;
    v_config JSONB;
    v_brand JSONB;
    v_voice JSONB;
    v_version INTEGER;
BEGIN
    SELECT c.id, b.config
    INTO v_chef_id, v_config
    FROM public.chefs c
    JOIN public.brand_configs b ON b.chef_id = c.id
    WHERE c.slug = 'ohorodnik-oleksandr'
      AND c.is_active = TRUE
      AND b.status = 'published'
    ORDER BY b.version DESC
    LIMIT 1
    FOR UPDATE OF c, b;

    IF v_chef_id IS NULL OR v_config IS NULL THEN
        RAISE EXCEPTION 'published BrandConfig for ohorodnik-oleksandr was not found'
            USING ERRCODE = 'P0002';
    END IF;

    v_brand := v_config->'brand';
    v_voice := COALESCE(v_brand->'voice', '{}'::jsonb)
        || jsonb_build_object('greeting', 'Готувати — це любити.');
    v_brand := v_brand || jsonb_build_object(
        'accent', '#7A1823',
        'font', 'serif',
        'voice', v_voice,
        'derived', jsonb_build_object(
            'accentPressed', '#6B0417',
            'accentOnDark', '#C45E60',
            'onAccent', '#FFFFFF',
            'lightCtaMode', 'accentFill'
        )
    );
    v_config := v_config || jsonb_build_object('brand', v_brand);

    UPDATE public.brand_configs
    SET status = 'archived'
    WHERE chef_id = v_chef_id AND status = 'published';

    SELECT COALESCE(MAX(version), 0) + 1
    INTO v_version
    FROM public.brand_configs
    WHERE chef_id = v_chef_id;

    INSERT INTO public.brand_configs (
        chef_id,
        version,
        status,
        config,
        published_at
    ) VALUES (
        v_chef_id,
        v_version,
        'published',
        v_config,
        NOW()
    );
END;
$$;

COMMIT;
