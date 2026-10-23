-- Migration 018: Finance (Pools & Expense Claims)
CREATE TABLE IF NOT EXISTS public.pools (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type            TEXT NOT NULL CHECK (type IN ('rest_stop','trip','event','custom')),
  title           TEXT NOT NULL,
  description     TEXT,
  event_id        UUID REFERENCES public.events(id) ON DELETE SET NULL,
  manager_user_id UUID REFERENCES public.users(id),
  target_amount   NUMERIC(10,2),
  status          TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed','settled')),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  deleted_at      TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.pool_contributions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pool_id         UUID NOT NULL REFERENCES public.pools(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES public.users(id),
  amount          NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  method          TEXT CHECK (method IN ('cash','transfer','stc_pay','apple_pay','other')),
  note            TEXT,
  paid_at         TIMESTAMPTZ DEFAULT NOW(),
  recorded_by     UUID REFERENCES public.users(id),
  UNIQUE(pool_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.expense_claims (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  claimant_user_id UUID NOT NULL REFERENCES public.users(id),
  pool_id         UUID REFERENCES public.pools(id),
  event_id        UUID REFERENCES public.events(id),
  title           TEXT NOT NULL,
  amount          NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  description     TEXT,
  receipt_url     TEXT,
  status          TEXT NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending','approved','rejected','paid')),
  decided_by      UUID REFERENCES public.users(id),
  decided_at      TIMESTAMPTZ,
  decision_note   TEXT,
  paid_at         TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_contributions_pool ON public.pool_contributions(pool_id);
CREATE INDEX IF NOT EXISTS idx_claims_status ON public.expense_claims(status);

ALTER TABLE public.pools ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pool_contributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_claims ENABLE ROW LEVEL SECURITY;

-- Pools policies
DROP POLICY IF EXISTS "pools_select" ON public.pools;
CREATE POLICY "pools_select" ON public.pools
  FOR SELECT TO authenticated
  USING (deleted_at IS NULL);

DROP POLICY IF EXISTS "pools_insert" ON public.pools;
CREATE POLICY "pools_insert" ON public.pools
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_admin()
    OR public.has_role('mod_hospitality'::app_role)
    OR manager_user_id = auth.uid()
  );

DROP POLICY IF EXISTS "pools_update" ON public.pools;
CREATE POLICY "pools_update" ON public.pools
  FOR UPDATE TO authenticated
  USING (
    public.is_admin()
    OR public.has_role('mod_hospitality'::app_role)
    OR manager_user_id = auth.uid()
  );

DROP POLICY IF EXISTS "pools_delete" ON public.pools;
CREATE POLICY "pools_delete" ON public.pools
  FOR DELETE TO authenticated
  USING (
    public.is_admin()
    OR public.has_role('mod_hospitality'::app_role)
    OR manager_user_id = auth.uid()
  );

-- Pool contributions policies
DROP POLICY IF EXISTS "contributions_select" ON public.pool_contributions;
CREATE POLICY "contributions_select" ON public.pool_contributions
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "contributions_insert" ON public.pool_contributions;
CREATE POLICY "contributions_insert" ON public.pool_contributions
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_admin()
    OR public.has_role('mod_hospitality'::app_role)
    OR EXISTS (
      SELECT 1 FROM public.pools p
      WHERE p.id = pool_id AND p.manager_user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "contributions_update" ON public.pool_contributions;
CREATE POLICY "contributions_update" ON public.pool_contributions
  FOR UPDATE TO authenticated
  USING (
    public.is_admin()
    OR public.has_role('mod_hospitality'::app_role)
    OR EXISTS (
      SELECT 1 FROM public.pools p
      WHERE p.id = pool_id AND p.manager_user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "contributions_delete" ON public.pool_contributions;
CREATE POLICY "contributions_delete" ON public.pool_contributions
  FOR DELETE TO authenticated
  USING (
    public.is_admin()
    OR public.has_role('mod_hospitality'::app_role)
    OR EXISTS (
      SELECT 1 FROM public.pools p
      WHERE p.id = pool_id AND p.manager_user_id = auth.uid()
    )
  );

-- Expense claims policies
DROP POLICY IF EXISTS "expense_claims_select" ON public.expense_claims;
CREATE POLICY "expense_claims_select" ON public.expense_claims
  FOR SELECT TO authenticated
  USING (
    claimant_user_id = auth.uid()
    OR public.is_admin()
    OR public.has_role('mod_hospitality'::app_role)
  );

DROP POLICY IF EXISTS "expense_claims_insert" ON public.expense_claims;
CREATE POLICY "expense_claims_insert" ON public.expense_claims
  FOR INSERT TO authenticated
  WITH CHECK (
    claimant_user_id = auth.uid()
    OR public.is_admin()
  );

DROP POLICY IF EXISTS "expense_claims_update" ON public.expense_claims;
CREATE POLICY "expense_claims_update" ON public.expense_claims
  FOR UPDATE TO authenticated
  USING (
    public.is_admin()
    OR public.has_role('mod_hospitality'::app_role)
    OR (claimant_user_id = auth.uid() AND status = 'pending')
  );

-- Storage bucket: receipts (private)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'receipts',
  'receipts',
  false,
  10485760, -- 10MB max
  ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/heic', 'application/pdf']
)
ON CONFLICT (id) DO UPDATE
SET public = false,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Storage policies for receipts
DROP POLICY IF EXISTS "Receipts read access" ON storage.objects;
CREATE POLICY "Receipts read access"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'receipts' AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR split_part(name, '/', 1) = auth.uid()::text
      OR owner = auth.uid()
      OR public.is_admin()
      OR public.has_role('mod_hospitality'::app_role)
    )
  );

DROP POLICY IF EXISTS "Users can upload receipts" ON storage.objects;
CREATE POLICY "Users can upload receipts"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'receipts' AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR split_part(name, '/', 1) = auth.uid()::text
      OR owner = auth.uid()
      OR public.is_admin()
    )
  );

DROP POLICY IF EXISTS "Users can update own receipts" ON storage.objects;
CREATE POLICY "Users can update own receipts"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'receipts' AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR split_part(name, '/', 1) = auth.uid()::text
      OR owner = auth.uid()
      OR public.is_admin()
    )
  );

DROP POLICY IF EXISTS "Users can delete own receipts" ON storage.objects;
CREATE POLICY "Users can delete own receipts"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'receipts' AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR split_part(name, '/', 1) = auth.uid()::text
      OR owner = auth.uid()
      OR public.is_admin()
    )
  );
