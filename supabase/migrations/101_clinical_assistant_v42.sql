-- PRD v4.2 — Clinical Assistant: hourly climate SSOT + environment rules.

CREATE TABLE IF NOT EXISTS public.shop_hourly_climate (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  hour_bucket timestamptz NOT NULL,
  climate_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  ssi integer NOT NULL DEFAULT 0,
  fetched_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (shop_id, hour_bucket)
);

CREATE INDEX IF NOT EXISTS idx_shop_hourly_climate_shop_hour
  ON public.shop_hourly_climate (shop_id, hour_bucket DESC);

ALTER TABLE public.shop_hourly_climate ENABLE ROW LEVEL SECURITY;

CREATE POLICY shop_hourly_climate_shop_read ON public.shop_hourly_climate
  FOR SELECT USING (
    shop_id IN (
      SELECT sm.shop_id FROM public.shop_memberships sm
      WHERE sm.user_id = auth.uid()
    )
  );

CREATE POLICY shop_hourly_climate_shop_write ON public.shop_hourly_climate
  FOR ALL USING (
    shop_id IN (
      SELECT sm.shop_id FROM public.shop_memberships sm
      WHERE sm.user_id = auth.uid()
        AND sm.role IN ('owner', 'director')
    )
  );

CREATE TABLE IF NOT EXISTS public.clinical_environment_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid REFERENCES public.shops(id) ON DELETE CASCADE,
  rule_key text NOT NULL,
  headline text NOT NULL DEFAULT '',
  narrative text NOT NULL DEFAULT '',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_clinical_environment_rules_shop
  ON public.clinical_environment_rules (shop_id, is_active);

ALTER TABLE public.clinical_environment_rules ENABLE ROW LEVEL SECURITY;

CREATE POLICY clinical_environment_rules_shop_read ON public.clinical_environment_rules
  FOR SELECT USING (
    shop_id IS NULL
    OR shop_id IN (
      SELECT sm.shop_id FROM public.shop_memberships sm
      WHERE sm.user_id = auth.uid()
    )
  );

CREATE POLICY clinical_environment_rules_shop_write ON public.clinical_environment_rules
  FOR ALL USING (
    shop_id IN (
      SELECT sm.shop_id FROM public.shop_memberships sm
      WHERE sm.user_id = auth.uid()
        AND sm.role IN ('owner', 'director')
    )
  );
