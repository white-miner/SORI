-- PRD v5.2 Phase E — persist ephemeral timer fields for multi-device catch-up.
-- chart_opened_at / current_step_started_at were previously local-cache only.

ALTER TABLE public.visit_operation_timers
  ADD COLUMN IF NOT EXISTS chart_opened_at timestamptz;

ALTER TABLE public.visit_operation_timers
  ADD COLUMN IF NOT EXISTS current_step_started_at timestamptz;

COMMENT ON COLUMN public.visit_operation_timers.chart_opened_at IS
  'PRD v5.2 — chart writer open timestamp for chart-active track sync.';
COMMENT ON COLUMN public.visit_operation_timers.current_step_started_at IS
  'PRD v5.2 — current care step start for multi-device remaining-time catch-up.';
