-- 재무 건전성 + 전자 동의서 PDF + 장기 미방문 프로모션

-- 1) 회원권 티켓 단가/결제액
alter table public.membership_tickets
  add column if not exists paid_amount int not null default 0,
  add column if not exists per_session_value int not null default 0;

comment on column public.membership_tickets.paid_amount is
  '회원권 결제 총액(원) — 부채(선수금) 인식';
comment on column public.membership_tickets.per_session_value is
  '1회당 노동 부채(원) = paid_amount / total_visits (반올림)';

-- 2) 고객 프로모션 발송 시각
alter table public.customers
  add column if not exists last_promotion_sent_at timestamptz;

comment on column public.customers.last_promotion_sent_at is
  '회원권 사용요청/프로모션 알림톡 마지막 발송 시각';

-- 3) 차트 동의서 PDF URL
alter table public.customer_charts
  add column if not exists consent_pdf_url text;

comment on column public.customer_charts.consent_pdf_url is
  '전자 동의서 PDF (consent_pdfs 버킷 public URL)';

-- chart_records 뷰가 있다면 컬럼 노출 (뷰 정의가 테이블 select * 이면 자동)

-- 4) 원장 월간 CAPA (Hell-Zone 기준, 기본 100회)
alter table public.shops
  add column if not exists monthly_capa int not null default 100;

comment on column public.shops.monthly_capa is
  '월간 소화 가능 회차 CAPA. 잔여 총합 > CAPA*1.2 시 Hell-Zone';

-- 5) consent_pdfs Public Storage 버킷
insert into storage.buckets (id, name, public)
values ('consent_pdfs', 'consent_pdfs', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "consent_pdfs_authenticated_insert" on storage.objects;
create policy "consent_pdfs_authenticated_insert"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'consent_pdfs');

drop policy if exists "consent_pdfs_authenticated_update" on storage.objects;
create policy "consent_pdfs_authenticated_update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'consent_pdfs')
  with check (bucket_id = 'consent_pdfs');

drop policy if exists "consent_pdfs_authenticated_delete" on storage.objects;
create policy "consent_pdfs_authenticated_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'consent_pdfs');

drop policy if exists "consent_pdfs_public_select" on storage.objects;
create policy "consent_pdfs_public_select"
  on storage.objects for select
  to public
  using (bucket_id = 'consent_pdfs');

-- anon 업로드도 MVP 허용 (웹 원장 세션 경계 완화)
drop policy if exists "consent_pdfs_anon_insert" on storage.objects;
create policy "consent_pdfs_anon_insert"
  on storage.objects for insert
  to anon
  with check (bucket_id = 'consent_pdfs');

-- 6) sync_membership_tickets — paid_amount / per_session_value 반영
create or replace function public.sync_membership_tickets_for_customer(
  p_customer_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  c record;
  item jsonb;
  tid text;
  tname text;
  total int;
  used int;
  exp date;
  paid int;
  per_val int;
begin
  select * into c from public.customers where id = p_customer_id;
  if not found then
    return;
  end if;

  delete from public.membership_tickets where customer_id = p_customer_id;

  if c.memberships is null or jsonb_typeof(c.memberships) <> 'array' then
    return;
  end if;

  for item in select * from jsonb_array_elements(c.memberships)
  loop
    tid := coalesce(nullif(item->>'id', ''), gen_random_uuid()::text);
    tname := coalesce(nullif(item->>'service_name', ''), '회원권');
    total := greatest(coalesce((item->>'total_visits')::int, 0), 0);
    used := greatest(coalesce((item->>'used_visits')::int, 0), 0);
    paid := greatest(coalesce((item->>'paid_amount')::int, 0), 0);
    per_val := greatest(coalesce((item->>'per_session_value')::int, 0), 0);
    if per_val <= 0 and paid > 0 and total > 0 then
      per_val := round(paid::numeric / total::numeric)::int;
    end if;
    if total <= 0 then
      continue;
    end if;
    begin
      exp := nullif(item->>'expires_at', '')::date;
    exception when others then
      exp := null;
    end;

    insert into public.membership_tickets (
      id, shop_id, customer_id, customer_phone_digits,
      ticket_name, total_visits, used_visits, expires_at, is_active,
      paid_amount, per_session_value, updated_at
    ) values (
      tid,
      c.shop_id,
      c.id,
      regexp_replace(coalesce(c.phone, ''), '[^0-9]', '', 'g'),
      tname,
      total,
      least(used, total),
      exp,
      (total - used) > 0,
      paid,
      per_val,
      now()
    )
    on conflict (id) do update set
      shop_id = excluded.shop_id,
      customer_id = excluded.customer_id,
      customer_phone_digits = excluded.customer_phone_digits,
      ticket_name = excluded.ticket_name,
      total_visits = excluded.total_visits,
      used_visits = excluded.used_visits,
      expires_at = excluded.expires_at,
      is_active = excluded.is_active,
      paid_amount = excluded.paid_amount,
      per_session_value = excluded.per_session_value,
      updated_at = now();
  end loop;
end;
$$;

grant execute on function public.sync_membership_tickets_for_customer(uuid)
  to anon, authenticated, service_role;
