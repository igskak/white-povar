-- AI-02: private, tenant-scoped generated recipes. Drafts are never catalog content.
BEGIN;

CREATE TABLE IF NOT EXISTS public.generated_recipe_drafts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    chef_id UUID NOT NULL REFERENCES public.chefs(id) ON DELETE CASCADE,
    recipe JSONB NOT NULL,
    allergen_warning TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT generated_recipe_drafts_ai_source CHECK (recipe->>'source' = 'ai_generated'),
    CONSTRAINT generated_recipe_drafts_ai_label CHECK (recipe->>'attribution' = 'Створено AI, не опублікований рецепт автора')
);
CREATE INDEX IF NOT EXISTS generated_recipe_drafts_owner_tenant_idx
    ON public.generated_recipe_drafts(user_id, chef_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS public.generated_recipe_draft_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    draft_id UUID NOT NULL REFERENCES public.generated_recipe_drafts(id) ON DELETE CASCADE,
    rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    safety_issue BOOLEAN NOT NULL DEFAULT FALSE,
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.generated_recipe_drafts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.generated_recipe_draft_feedback ENABLE ROW LEVEL SECURITY;
CREATE POLICY wp_generated_recipe_drafts_own ON public.generated_recipe_drafts FOR ALL TO authenticated
    USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY wp_generated_recipe_draft_feedback_own ON public.generated_recipe_draft_feedback FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM public.generated_recipe_drafts d WHERE d.id = draft_id AND d.user_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM public.generated_recipe_drafts d WHERE d.id = draft_id AND d.user_id = auth.uid()));

-- Run daily from the existing platform scheduler. This hard-deletes draft and feedback;
-- it retains neither prompts nor identifiable feedback after the retention window.
CREATE OR REPLACE FUNCTION public.purge_expired_generated_recipe_drafts()
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE deleted_count INTEGER;
BEGIN
    DELETE FROM generated_recipe_drafts WHERE updated_at < now() - interval '30 days';
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;

COMMIT;
