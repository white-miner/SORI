-- SORI 공식 카카오톡 알림톡 포인트 + 발송 로그 (인투펫형 마진 뼈대)
-- 건당 차감: 앱에서 65P / 로그 margin_amount 기본 50원

alter table public.shops
  add column if not exists kakao_point int not null default 0,
  add column if not exists is_pro boolean not null default false;

comment on column public.shops.kakao_point is
  '잔여 알림톡 포인트 (발송 1건당 앱에서 65P 차감)';
comment on column public.shops.is_pro is
  '프로 플랜 여부 (알림톡/마진 상품 게이트)';

create table if not exists public.kakao_msg_logs (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  customer_phone text not null default '',
  template_code text not null default '',
  content text not null default '',
  status text not null default 'SUCCESS'
    check (status in ('SUCCESS', 'FAIL')),
  margin_amount int not null default 50,
  created_at timestamptz not null default now()
);

create index if not exists idx_kakao_msg_logs_shop_created
  on public.kakao_msg_logs (shop_id, created_at desc);

comment on table public.kakao_msg_logs is
  '카카오 알림톡 발송 로그 (현재 MOCK 성공 Insert 포함)';
comment on column public.kakao_msg_logs.margin_amount is
  '건당 마진(원) — 기본 50';

alter table public.kakao_msg_logs enable row level security;

drop policy if exists "mvp_kakao_msg_logs_select" on public.kakao_msg_logs;
drop policy if exists "mvp_kakao_msg_logs_insert" on public.kakao_msg_logs;
create policy "mvp_kakao_msg_logs_select"
  on public.kakao_msg_logs for select using (true);
create policy "mvp_kakao_msg_logs_insert"
  on public.kakao_msg_logs for insert with check (true);

-- 원자적 포인트 차감 + MOCK 성공 로그
create or replace function public.send_kakao_alimtalk_mock(
  p_shop_id uuid,
  p_customer_phone text,
  p_template_code text,
  p_content text,
  p_cost int default 65,
  p_margin int default 50
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_points int;
  v_log_id uuid;
  v_cost int := greatest(coalesce(p_cost, 65), 1);
begin
  select kakao_point into v_points
  from public.shops
  where id = p_shop_id
  for update;

  if v_points is null then
    raise exception 'shop_not_found' using errcode = 'P0002';
  end if;

  if v_points < v_cost then
    raise exception 'insufficient_kakao_point' using errcode = 'P0001';
  end if;

  update public.shops
  set
    kakao_point = kakao_point - v_cost,
    updated_at = now()
  where id = p_shop_id;

  insert into public.kakao_msg_logs (
    shop_id,
    customer_phone,
    template_code,
    content,
    status,
    margin_amount
  ) values (
    p_shop_id,
    coalesce(p_customer_phone, ''),
    coalesce(p_template_code, ''),
    coalesce(p_content, ''),
    'SUCCESS',
    coalesce(p_margin, 50)
  )
  returning id into v_log_id;

  return jsonb_build_object(
    'log_id', v_log_id,
    'kakao_point', v_points - v_cost,
    'status', 'SUCCESS',
    'cost', v_cost,
    'margin_amount', coalesce(p_margin, 50)
  );
end;
$$;

grant execute on function public.send_kakao_alimtalk_mock(
  uuid, text, text, text, int, int
) to anon, authenticated, service_role;

-- 도입 직후 테스트용: 잔액 0인 기존 샵에 1000P 시드
update public.shops
set kakao_point = 1000
where kakao_point = 0;
