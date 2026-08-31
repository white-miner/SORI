-- PRD v3.1: 5-phase visit (plan) + mentor presence heartbeat.

ALTER TABLE public.visit_sessions
  DROP CONSTRAINT IF EXISTS visit_sessions_phase_check;

ALTER TABLE public.visit_sessions
  ADD CONSTRAINT visit_sessions_phase_check
  CHECK (phase IN ('shoot', 'consult', 'plan', 'consent', 'publish', 'done'));

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS last_seen_at timestamptz;

COMMENT ON COLUMN public.profiles.last_seen_at IS
  'Foreground heartbeat — online ring if within 5 minutes (PRD v3.1).';
