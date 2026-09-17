-- PRD v3.0 Phase 1: Visit OS — on-site visit session SSOT.

CREATE TABLE IF NOT EXISTS public.visit_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  customer_name text NOT NULL DEFAULT '',
  chart_draft_id uuid REFERENCES public.customer_charts(id) ON DELETE SET NULL,
  phase text NOT NULL DEFAULT 'shoot'
    CHECK (phase IN ('shoot', 'consult', 'consent', 'publish', 'done')),
  started_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_visit_sessions_shop_day
  ON public.visit_sessions (shop_id, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_visit_sessions_customer
  ON public.visit_sessions (customer_id, started_at DESC);

ALTER TABLE public.visit_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY visit_sessions_shop_read ON public.visit_sessions
  FOR SELECT USING (
    shop_id IN (
      SELECT sm.shop_id FROM public.shop_memberships sm
      WHERE sm.user_id = auth.uid()
    )
  );

CREATE POLICY visit_sessions_shop_write ON public.visit_sessions
  FOR ALL USING (
    shop_id IN (
      SELECT sm.shop_id FROM public.shop_memberships sm
      WHERE sm.user_id = auth.uid()
        AND sm.role IN ('owner', 'director')
    )
  );

COMMENT ON TABLE public.visit_sessions IS
  'Visit OS SSOT — shoot/consult/consent/publish loop per customer visit (PRD v3.0).';
