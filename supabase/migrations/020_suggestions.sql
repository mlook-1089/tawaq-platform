-- Migration 020: Member Suggestions
DO $$ BEGIN
  CREATE TYPE suggestion_type AS ENUM ('event','location','feature','general');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE suggestion_status AS ENUM ('open','under_review','accepted','rejected','implemented');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS public.suggestions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES public.users(id),
  type            suggestion_type NOT NULL,
  title           TEXT NOT NULL CHECK (LENGTH(title) BETWEEN 3 AND 150),
  description     TEXT CHECK (LENGTH(description) <= 2000),
  status          suggestion_status NOT NULL DEFAULT 'open',
  decided_by      UUID REFERENCES public.users(id),
  decided_at      TIMESTAMPTZ,
  decision_note   TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  deleted_at      TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.suggestion_votes (
  suggestion_id   UUID NOT NULL REFERENCES public.suggestions(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES public.users(id),
  vote            SMALLINT NOT NULL CHECK (vote IN (-1,1)),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (suggestion_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_suggestions_status ON public.suggestions(status, created_at DESC);

ALTER TABLE public.suggestions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suggestion_votes ENABLE ROW LEVEL SECURITY;

-- Suggestions policies
DROP POLICY IF EXISTS "suggestions_select" ON public.suggestions;
CREATE POLICY "suggestions_select" ON public.suggestions
  FOR SELECT TO authenticated
  USING (deleted_at IS NULL);

DROP POLICY IF EXISTS "suggestions_insert" ON public.suggestions;
CREATE POLICY "suggestions_insert" ON public.suggestions
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "suggestions_update" ON public.suggestions;
CREATE POLICY "suggestions_update" ON public.suggestions
  FOR UPDATE TO authenticated
  USING (
    (user_id = auth.uid() AND status = 'open')
    OR public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid() AND role::text LIKE 'mod_%'
    )
  );

DROP POLICY IF EXISTS "suggestions_delete" ON public.suggestions;
CREATE POLICY "suggestions_delete" ON public.suggestions
  FOR DELETE TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_admin()
  );

-- Suggestion votes policies
DROP POLICY IF EXISTS "suggestion_votes_select" ON public.suggestion_votes;
CREATE POLICY "suggestion_votes_select" ON public.suggestion_votes
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "suggestion_votes_insert" ON public.suggestion_votes;
CREATE POLICY "suggestion_votes_insert" ON public.suggestion_votes
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "suggestion_votes_update" ON public.suggestion_votes;
CREATE POLICY "suggestion_votes_update" ON public.suggestion_votes
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "suggestion_votes_delete" ON public.suggestion_votes;
CREATE POLICY "suggestion_votes_delete" ON public.suggestion_votes
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- Function to compute suggestion score
CREATE OR REPLACE FUNCTION public.suggestion_score(sid uuid)
RETURNS INT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COALESCE(SUM(vote), 0)::INT
  FROM public.suggestion_votes
  WHERE suggestion_id = sid;
$$;
