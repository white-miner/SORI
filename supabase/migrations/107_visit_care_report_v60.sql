-- PRD v6.0 — structured care report JSON + overtime seconds on timer.

ALTER TABLE customer_charts
  ADD COLUMN IF NOT EXISTS care_report_json jsonb,
  ADD COLUMN IF NOT EXISTS care_report_generated_at timestamptz;

ALTER TABLE visit_operation_timers
  ADD COLUMN IF NOT EXISTS overtime_seconds int NOT NULL DEFAULT 0;

COMMENT ON COLUMN customer_charts.care_report_json IS
  'PRD v6.0 VisitCareReport snapshot for B2C page + re-send';
COMMENT ON COLUMN visit_operation_timers.overtime_seconds IS
  'PRD v6.0 정성(overtime) seconds persisted at visit end';
