-- PRD v4.5 — Aesthetic Time Management (3-button timer + 5 preset slots).

CREATE TABLE IF NOT EXISTS public.care_program_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  slot_index smallint NOT NULL CHECK (slot_index >= 0 AND slot_index <= 4),
  name text NOT NULL DEFAULT '',
  steps jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (shop_id, slot_index)
);

CREATE INDEX IF NOT EXISTS idx_care_program_templates_shop
  ON public.care_program_templates (shop_id, slot_index);

ALTER TABLE public.care_program_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY care_program_templates_shop_rw ON public.care_program_templates
  FOR ALL USING (
    shop_id IN (
      SELECT sm.shop_id FROM public.shop_memberships sm
      WHERE sm.user_id = auth.uid()
        AND sm.role IN ('owner', 'director')
    )
  );

CREATE TABLE IF NOT EXISTS public.visit_operation_timers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_session_id uuid NOT NULL REFERENCES public.visit_sessions(id) ON DELETE CASCADE,
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  template_id uuid REFERENCES public.care_program_templates(id) ON DELETE SET NULL,
  template_snapshot jsonb NOT NULL DEFAULT '[]'::jsonb,
  consultation_started_at timestamptz,
  chart_active_seconds integer NOT NULL DEFAULT 0,
  care_started_at timestamptz,
  care_ended_at timestamptz,
  visit_ended_at timestamptz,
  current_step_index integer NOT NULL DEFAULT 0,
  step_results jsonb NOT NULL DEFAULT '[]'::jsonb,
  after_photo_captured boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'idle'
    CHECK (status IN (
      'idle', 'consulting', 'prep', 'care', 'care_overtime', 'post_care', 'done'
    )),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (visit_session_id)
);

CREATE INDEX IF NOT EXISTS idx_visit_operation_timers_shop
  ON public.visit_operation_timers (shop_id, updated_at DESC);

ALTER TABLE public.visit_operation_timers ENABLE ROW LEVEL SECURITY;

CREATE POLICY visit_operation_timers_shop_rw ON public.visit_operation_timers
  FOR ALL USING (
    shop_id IN (
      SELECT sm.shop_id FROM public.shop_memberships sm
      WHERE sm.user_id = auth.uid()
        AND sm.role IN ('owner', 'director')
    )
  );

CREATE TABLE IF NOT EXISTS public.visit_operation_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_session_id uuid NOT NULL REFERENCES public.visit_sessions(id) ON DELETE CASCADE,
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_visit_operation_events_session
  ON public.visit_operation_events (visit_session_id, occurred_at DESC);

ALTER TABLE public.visit_operation_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY visit_operation_events_shop_rw ON public.visit_operation_events
  FOR ALL USING (
    shop_id IN (
      SELECT sm.shop_id FROM public.shop_memberships sm
      WHERE sm.user_id = auth.uid()
        AND sm.role IN ('owner', 'director')
    )
  );

COMMENT ON TABLE public.care_program_templates IS
  'PRD v4.5 — max 5 care timer presets per shop (slot 0-4), 1-5 steps each.';
COMMENT ON TABLE public.visit_operation_timers IS
  'PRD v4.5 — per-visit timer SSOT (total/chart/care tracks).';
COMMENT ON TABLE public.visit_operation_events IS
  'PRD v4.5 — append-only visit timer audit log.';
