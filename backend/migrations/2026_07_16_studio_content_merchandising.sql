-- STUDIO-04: tenant-scoped internal authoring.  Consumer tables remain the
-- source of truth; unpublished recipes use is_public=false and cannot pass
-- the existing consumer policies/endpoints.
BEGIN;

CREATE TABLE IF NOT EXISTS public.studio_content_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    actor_id UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    entity_type TEXT NOT NULL CHECK (entity_type IN ('content', 'collection', 'merchandising')),
    entity_id UUID,
    action TEXT NOT NULL,
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS studio_content_audit_tenant_idx ON public.studio_content_audit(chef_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.studio_scheduled_publications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    entity_type TEXT NOT NULL CHECK (entity_type IN ('content', 'collection')),
    entity_id UUID NOT NULL,
    publish_at TIMESTAMPTZ NOT NULL,
    created_by UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (entity_type, entity_id)
);
CREATE INDEX IF NOT EXISTS studio_scheduled_publications_due_idx ON public.studio_scheduled_publications(publish_at);

CREATE OR REPLACE FUNCTION public.studio_save_content(p_chef_id UUID, p_user_id UUID, p_content_id UUID, p_values JSONB)
RETURNS SETOF public.recipes LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result public.recipes%ROWTYPE; scheduled_at TIMESTAMPTZ;
BEGIN
  IF p_content_id IS NULL THEN
    INSERT INTO recipes (chef_id,title,description,content_kind,prep_time_minutes,cook_time_minutes,servings,instructions,instructions_structured,video_url,video_file_path,tags,is_featured,is_premium,is_public,category_id)
    VALUES (p_chef_id,p_values->>'title',p_values->>'description',p_values->>'content_kind',coalesce((p_values->>'prep_time_minutes')::int,0),coalesce((p_values->>'cook_time_minutes')::int,0),coalesce((p_values->>'servings')::int,1),coalesce(array_to_string(ARRAY(SELECT jsonb_array_elements_text(coalesce(p_values->'instructions','[]'))), E'\n'),''),coalesce(p_values->'instructions','[]'),p_values->>'video_url',p_values->>'video_file_path',ARRAY(SELECT jsonb_array_elements_text(coalesce(p_values->'tags','[]'))),coalesce((p_values->>'is_featured')::boolean,false),coalesce((p_values->>'is_premium')::boolean,false),false,'20000000-0000-0000-0000-000000000099') RETURNING * INTO result;
  ELSE
    UPDATE recipes SET title=p_values->>'title',description=p_values->>'description',content_kind=p_values->>'content_kind',prep_time_minutes=coalesce((p_values->>'prep_time_minutes')::int,0),cook_time_minutes=coalesce((p_values->>'cook_time_minutes')::int,0),servings=coalesce((p_values->>'servings')::int,1),instructions=coalesce(array_to_string(ARRAY(SELECT jsonb_array_elements_text(coalesce(p_values->'instructions','[]'))), E'\n'),''),instructions_structured=coalesce(p_values->'instructions','[]'),video_url=p_values->>'video_url',video_file_path=p_values->>'video_file_path',tags=ARRAY(SELECT jsonb_array_elements_text(coalesce(p_values->'tags','[]'))),is_featured=coalesce((p_values->>'is_featured')::boolean,false),is_premium=coalesce((p_values->>'is_premium')::boolean,false),updated_at=now() WHERE id=p_content_id AND chef_id=p_chef_id RETURNING * INTO result;
    IF NOT FOUND THEN RETURN; END IF;
  END IF;
  scheduled_at := nullif(p_values->>'publish_at','')::timestamptz;
  IF scheduled_at > now() THEN INSERT INTO studio_scheduled_publications(chef_id,entity_type,entity_id,publish_at,created_by) VALUES(p_chef_id,'content',result.id,scheduled_at,p_user_id) ON CONFLICT(entity_type,entity_id) DO UPDATE SET publish_at=EXCLUDED.publish_at,created_by=EXCLUDED.created_by; END IF;
  INSERT INTO studio_content_audit(chef_id,actor_id,entity_type,entity_id,action,details) VALUES(p_chef_id,p_user_id,'content',result.id,CASE WHEN p_content_id IS NULL THEN 'created_draft' ELSE 'updated_draft' END,jsonb_build_object('scheduledAt',scheduled_at));
  RETURN NEXT result;
END $$;

CREATE OR REPLACE FUNCTION public.studio_publish_content(p_chef_id UUID, p_user_id UUID, p_content_id UUID)
RETURNS SETOF public.recipes LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result public.recipes%ROWTYPE;
BEGIN
  UPDATE recipes SET is_public=true,updated_at=now() WHERE id=p_content_id AND chef_id=p_chef_id RETURNING * INTO result;
  IF NOT FOUND THEN RETURN; END IF;
  DELETE FROM studio_scheduled_publications WHERE entity_type='content' AND entity_id=result.id;
  INSERT INTO studio_content_audit(chef_id,actor_id,entity_type,entity_id,action) VALUES(p_chef_id,p_user_id,'content',result.id,'published');
  RETURN NEXT result;
END $$;

CREATE OR REPLACE FUNCTION public.studio_save_collection(p_chef_id UUID,p_user_id UUID,p_collection_id UUID,p_values JSONB)
RETURNS SETOF public.collections LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result public.collections%ROWTYPE; item JSONB; ordinal INT := 0; scheduled_at TIMESTAMPTZ;
BEGIN
  IF p_collection_id IS NULL THEN INSERT INTO collections(chef_id,slug,title_i18n,description_i18n,cover_url,is_premium,status) VALUES(p_chef_id,p_values->>'slug',p_values->'title_i18n',coalesce(p_values->'description_i18n','{}'),p_values->>'cover_url',coalesce((p_values->>'is_premium')::boolean,false),'draft') RETURNING * INTO result;
  ELSE UPDATE collections SET slug=p_values->>'slug',title_i18n=p_values->'title_i18n',description_i18n=coalesce(p_values->'description_i18n','{}'),cover_url=p_values->>'cover_url',is_premium=coalesce((p_values->>'is_premium')::boolean,false),updated_at=now() WHERE id=p_collection_id AND chef_id=p_chef_id RETURNING * INTO result; IF NOT FOUND THEN RETURN; END IF; DELETE FROM collection_items WHERE collection_id=result.id; END IF;
  FOR item IN SELECT * FROM jsonb_array_elements(coalesce(p_values->'items','[]')) LOOP
    IF NOT EXISTS(SELECT 1 FROM recipes WHERE id=(item->>'recipe_id')::uuid AND chef_id=p_chef_id) THEN RAISE EXCEPTION 'Collection material must belong to tenant'; END IF;
    INSERT INTO collection_items(collection_id,recipe_id,position,is_preview) VALUES(result.id,(item->>'recipe_id')::uuid,ordinal,coalesce((item->>'is_preview')::boolean,false)); ordinal:=ordinal+1;
  END LOOP;
  scheduled_at := nullif(p_values->>'publish_at','')::timestamptz;
  IF scheduled_at > now() THEN INSERT INTO studio_scheduled_publications(chef_id,entity_type,entity_id,publish_at,created_by) VALUES(p_chef_id,'collection',result.id,scheduled_at,p_user_id) ON CONFLICT(entity_type,entity_id) DO UPDATE SET publish_at=EXCLUDED.publish_at,created_by=EXCLUDED.created_by; END IF;
  INSERT INTO studio_content_audit(chef_id,actor_id,entity_type,entity_id,action,details) VALUES(p_chef_id,p_user_id,'collection',result.id,CASE WHEN p_collection_id IS NULL THEN 'created_draft' ELSE 'updated_draft' END,jsonb_build_object('scheduledAt',scheduled_at)); RETURN NEXT result;
END $$;

CREATE OR REPLACE FUNCTION public.studio_publish_collection(p_chef_id UUID,p_user_id UUID,p_collection_id UUID)
RETURNS SETOF public.collections LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result public.collections%ROWTYPE;
BEGIN UPDATE collections SET status='published',published_at=coalesce(published_at,now()),updated_at=now() WHERE id=p_collection_id AND chef_id=p_chef_id RETURNING * INTO result; IF NOT FOUND THEN RETURN; END IF; DELETE FROM studio_scheduled_publications WHERE entity_type='collection' AND entity_id=result.id; INSERT INTO studio_content_audit(chef_id,actor_id,entity_type,entity_id,action) VALUES(p_chef_id,p_user_id,'collection',result.id,'published'); RETURN NEXT result; END $$;

CREATE OR REPLACE FUNCTION public.studio_save_merchandising(p_chef_id UUID,p_user_id UUID,p_values JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE product public.products%ROWTYPE; offer public.offers%ROWTYPE; collection_uuid UUID := nullif(p_values->>'collection_id','')::uuid; active_status TEXT := CASE WHEN coalesce((p_values->>'active')::boolean,false) THEN 'active' ELSE 'draft' END;
BEGIN
  IF collection_uuid IS NOT NULL AND NOT EXISTS(SELECT 1 FROM collections WHERE id=collection_uuid AND chef_id=p_chef_id) THEN RAISE EXCEPTION 'Collection must belong to tenant'; END IF;
  INSERT INTO products(chef_id,product_key,kind,status) VALUES(p_chef_id,p_values->>'product_key',p_values->>'kind',active_status) ON CONFLICT(chef_id,product_key) DO UPDATE SET kind=EXCLUDED.kind,status=EXCLUDED.status,updated_at=now() RETURNING * INTO product;
  INSERT INTO offers(chef_id,product_id,offer_key,status) VALUES(p_chef_id,product.id,p_values->>'offer_key',active_status) ON CONFLICT(chef_id,offer_key) DO UPDATE SET product_id=EXCLUDED.product_id,status=EXCLUDED.status,updated_at=now() RETURNING * INTO offer;
  DELETE FROM product_content WHERE product_id=product.id;
  IF collection_uuid IS NOT NULL THEN INSERT INTO product_content(product_id,chef_id,collection_id) VALUES(product.id,p_chef_id,collection_uuid); END IF;
  INSERT INTO studio_content_audit(chef_id,actor_id,entity_type,entity_id,action) VALUES(p_chef_id,p_user_id,'merchandising',product.id,'saved');
  RETURN jsonb_build_object('productId',product.id,'offerId',offer.id,'status',active_status);
END $$;

ALTER TABLE public.studio_content_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.studio_scheduled_publications ENABLE ROW LEVEL SECURITY;
COMMIT;
