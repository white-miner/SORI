-- PRD v4.0 Sprint 4.0-A/B: Operation Manual — weather, SOS, biometrics, hold phase.

ALTER TABLE public.shops
  ADD COLUMN IF NOT EXISTS latitude double precision,
  ADD COLUMN IF NOT EXISTS longitude double precision;

COMMENT ON COLUMN public.shops.latitude IS
  'Geocoded from address — KMA short-term forecast grid input (PRD v4.0).';
COMMENT ON COLUMN public.shops.longitude IS
  'Geocoded from address — KMA short-term forecast grid input (PRD v4.0).';

CREATE TABLE IF NOT EXISTS public.shop_daily_context (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  context_date date NOT NULL DEFAULT (timezone('Asia/Seoul', now()))::date,
  weather_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  fetched_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (shop_id, context_date)
);

CREATE INDEX IF NOT EXISTS idx_shop_daily_context_shop_date
  ON public.shop_daily_context (shop_id, context_date DESC);

ALTER TABLE public.shop_daily_context ENABLE ROW LEVEL SECURITY;

CREATE POLICY shop_daily_context_shop_read ON public.shop_daily_context
  FOR SELECT USING (
    shop_id IN (
      SELECT sm.shop_id FROM public.shop_memberships sm
      WHERE sm.user_id = auth.uid()
    )
  );

CREATE POLICY shop_daily_context_shop_write ON public.shop_daily_context
  FOR ALL USING (
    shop_id IN (
      SELECT sm.shop_id FROM public.shop_memberships sm
      WHERE sm.user_id = auth.uid()
        AND sm.role IN ('owner', 'director')
    )
  );

CREATE TABLE IF NOT EXISTS public.sos_keyword_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid REFERENCES public.shops(id) ON DELETE CASCADE,
  keyword text NOT NULL,
  grade text NOT NULL CHECK (grade IN ('s1', 's2', 's3')),
  headline text NOT NULL DEFAULT '',
  narrative text NOT NULL DEFAULT '',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sos_keyword_rules_shop
  ON public.sos_keyword_rules (shop_id, is_active);

ALTER TABLE public.sos_keyword_rules ENABLE ROW LEVEL SECURITY;

CREATE POLICY sos_keyword_rules_shop_read ON public.sos_keyword_rules
  FOR SELECT USING (
    shop_id IS NULL
    OR shop_id IN (
      SELECT sm.shop_id FROM public.shop_memberships sm
      WHERE sm.user_id = auth.uid()
    )
  );

CREATE POLICY sos_keyword_rules_shop_write ON public.sos_keyword_rules
  FOR ALL USING (
    shop_id IN (
      SELECT sm.shop_id FROM public.shop_memberships sm
      WHERE sm.user_id = auth.uid()
        AND sm.role IN ('owner', 'director')
    )
  );

ALTER TABLE public.customer_charts
  ADD COLUMN IF NOT EXISTS visit_biometrics jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.customer_charts.visit_biometrics IS
  'PRD v4.0 — sleep/cycle/alcohol quick pad (0=ok,1=caution,2=active).';

ALTER TABLE public.visit_sessions
  DROP CONSTRAINT IF EXISTS visit_sessions_phase_check;

ALTER TABLE public.visit_sessions
  ADD CONSTRAINT visit_sessions_phase_check
  CHECK (phase IN ('shoot', 'consult', 'plan', 'consent', 'publish', 'done', 'hold'));

COMMENT ON COLUMN public.visit_sessions.phase IS
  'Visit phase; hold = procedure deferred, home-care still required (PRD v4.0).';
