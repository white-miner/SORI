-- Phase CRM-1: Today Care Board — manual schedule + customer lead requests.

CREATE TABLE IF NOT EXISTS public.care_schedule_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  customer_id uuid REFERENCES public.customers(id) ON DELETE SET NULL,
  customer_name text NOT NULL DEFAULT '',
  customer_phone text,
  scheduled_at timestamptz NOT NULL,
  care_label text NOT NULL DEFAULT '',
  note text NOT NULL DEFAULT '',
  source text NOT NULL DEFAULT 'manual'
    CHECK (source IN ('manual', 'customerLead')),
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled', 'completed', 'cancelled')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_care_schedule_shop_day
  ON public.care_schedule_entries (shop_id, scheduled_at);

ALTER TABLE public.care_schedule_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY care_schedule_shop_read ON public.care_schedule_entries
  FOR SELECT USING (
    shop_id IN (
      SELECT sm.shop_id FROM public.shop_memberships sm
      WHERE sm.user_id = auth.uid()
    )
  );

CREATE POLICY care_schedule_shop_write ON public.care_schedule_entries
  FOR ALL USING (
    shop_id IN (
      SELECT sm.shop_id FROM public.shop_memberships sm
      WHERE sm.user_id = auth.uid()
        AND sm.role IN ('owner', 'director')
    )
  );

CREATE POLICY care_schedule_lead_insert ON public.care_schedule_entries
  FOR INSERT WITH CHECK (source = 'customerLead');

COMMENT ON TABLE public.care_schedule_entries IS
  'Today Care Board — director manual + customer preferred schedule leads (not Naver sync).';
