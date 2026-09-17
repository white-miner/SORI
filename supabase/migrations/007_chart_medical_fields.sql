-- 알레르기·민감·부작용은 고객 마스터가 아니라 방문 차트에 기록한다.
alter table public.customer_charts
  add column if not exists allergy_notes text default '',
  add column if not exists skin_sensitivity text default '',
  add column if not exists side_effect_history text default '';
