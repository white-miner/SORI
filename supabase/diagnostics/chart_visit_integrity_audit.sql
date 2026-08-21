-- =============================================================================
-- Chart visit_number integrity audit
-- Run in Supabase SQL Editor against production/staging.
-- Related app defense: unique(customer_id, visit_number) bump-retry on INSERT.
-- =============================================================================

-- 1) Duplicate visit_number rows for the same customer (should return 0 rows)
select
  customer_id,
  visit_number,
  count(*) as row_count,
  array_agg(id order by created_at) as chart_ids,
  array_agg(care_name order by created_at) as care_names
from public.customer_charts
group by customer_id, visit_number
having count(*) > 1
order by row_count desc, customer_id, visit_number;

-- 2) Visit sequence gaps / max per customer (spot missing or jumped sessions)
select
  c.customer_id,
  cu.name as customer_name,
  cu.phone,
  count(*) as chart_count,
  min(c.visit_number) as min_visit,
  max(c.visit_number) as max_visit,
  -- expected contiguous count if visits are 1..max with no gaps/dupes
  max(c.visit_number) - min(c.visit_number) + 1 as span_if_contiguous,
  count(*) <> (max(c.visit_number) - min(c.visit_number) + 1) as has_gap_or_dupe_signal
from public.customer_charts c
left join public.customers cu on cu.id = c.customer_id
group by c.customer_id, cu.name, cu.phone
having count(*) <> (max(c.visit_number) - min(c.visit_number) + 1)
   or min(c.visit_number) <> 1
order by has_gap_or_dupe_signal desc, chart_count desc;

-- 3) Full timeline dump for a suspicious customer (replace :customer_id)
-- select
--   id,
--   shop_id,
--   visit_number,
--   care_name,
--   visit_checked,
--   created_at,
--   updated_at
-- from public.customer_charts
-- where customer_id = ':customer_id'
-- order by visit_number asc, created_at asc;

-- 4) Confirm unique constraint still exists
select
  i.relname as index_name,
  pg_get_indexdef(i.oid) as index_def
from pg_class t
join pg_index x on x.indrelid = t.oid
join pg_class i on i.oid = x.indexrelid
join pg_namespace n on n.oid = t.relnamespace
where n.nspname = 'public'
  and t.relname = 'customer_charts'
  and x.indisunique
  and pg_get_indexdef(i.oid) ilike '%visit_number%';

-- 5) Same phone, multiple customer_ids (common cause of "mixed sessions")
select
  regexp_replace(coalesce(phone, ''), '[^0-9]', '', 'g') as phone_digits,
  shop_id,
  count(*) as customer_rows,
  array_agg(id) as customer_ids,
  array_agg(name) as names
from public.customers
where length(regexp_replace(coalesce(phone, ''), '[^0-9]', '', 'g')) >= 10
group by 1, shop_id
having count(*) > 1
order by customer_rows desc;
