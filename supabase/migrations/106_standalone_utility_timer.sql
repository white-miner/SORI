-- PRD v5.3 — standalone utility timer logs (no visit session required)

ALTER TABLE public.visit_operation_timers
  DROP CONSTRAINT IF EXISTS visit_operation_timers_visit_session_id_fkey;

ALTER TABLE public.visit_operation_timers
  ALTER COLUMN visit_session_id DROP NOT NULL;

ALTER TABLE public.visit_operation_timers
  DROP CONSTRAINT IF EXISTS visit_operation_timers_visit_session_id_key;

CREATE UNIQUE INDEX IF NOT EXISTS visit_operation_timers_session_unique
  ON public.visit_operation_timers (visit_session_id)
  WHERE visit_session_id IS NOT NULL;

ALTER TABLE public.visit_operation_timers
  ADD CONSTRAINT visit_operation_timers_visit_session_id_fkey
  FOREIGN KEY (visit_session_id) REFERENCES public.visit_sessions(id)
  ON DELETE CASCADE;

ALTER TABLE public.visit_operation_timers
  ADD COLUMN IF NOT EXISTS utility_source text;

COMMENT ON COLUMN public.visit_operation_timers.utility_source IS
  'PRD v5.3 — standalone_timer | count_tool when visit_session_id IS NULL';

ALTER TABLE public.visit_operation_events
  DROP CONSTRAINT IF EXISTS visit_operation_events_visit_session_id_fkey;

ALTER TABLE public.visit_operation_events
  ALTER COLUMN visit_session_id DROP NOT NULL;

ALTER TABLE public.visit_operation_events
  ADD CONSTRAINT visit_operation_events_visit_session_id_fkey
  FOREIGN KEY (visit_session_id) REFERENCES public.visit_sessions(id)
  ON DELETE CASCADE;

ALTER TABLE public.visit_operation_events
  ADD COLUMN IF NOT EXISTS utility_source text;

ALTER TABLE public.visit_operation_events
  ADD COLUMN IF NOT EXISTS timer_id uuid REFERENCES public.visit_operation_timers(id) ON DELETE SET NULL;
