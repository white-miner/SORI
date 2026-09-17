-- Customer identity & medical history fields for aesthetic charts

alter table public.customers
  add column if not exists gender text check (gender in ('female', 'male')),
  add column if not exists birth_date date,
  add column if not exists address text default '',
  add column if not exists occupation text default '',
  add column if not exists allergy_notes text default '',
  add column if not exists medication_history text default '',
  add column if not exists home_care_habits text default '';
