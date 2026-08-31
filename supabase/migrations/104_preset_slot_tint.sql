-- PRD v4.5+ — preset slot tint color (iOS native palette key).

ALTER TABLE public.care_program_templates
  ADD COLUMN IF NOT EXISTS slot_tint text NOT NULL DEFAULT 'green';

COMMENT ON COLUMN public.care_program_templates.slot_tint IS
  'iOS tint key: red | green | orange | purple | blue';
