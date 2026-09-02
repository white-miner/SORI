-- PRD v7.2 — [적용 범위] + [혜택 종류] + [값] 키워드 조립 문법의 저장 형태.
--
-- scope/target_id/percent_off 는 조회 조건과 산술의 대상이므로 jsonb 가 아니라 컬럼이다.
-- 견적 화면은 "이 패키지에 걸린 혜택만" 인덱스로 걸러야 하고 퍼센트는 SQL 에서 곱한다.

alter table public.program_promotions
  add column if not exists scope text not null default 'global',
  add column if not exists target_id uuid,
  add column if not exists percent_off numeric(5,2) not null default 0,
  add column if not exists gift_qty int not null default 0,
  add column if not exists last_used_at timestamptz,
  add column if not exists use_count int not null default 0;

alter table public.program_promotions
  drop constraint if exists program_promotions_scope_check;
alter table public.program_promotions
  add constraint program_promotions_scope_check
  check (
    scope in ('global', 'category', 'package')
    and (scope = 'global') = (target_id is null)
  );

alter table public.program_promotions
  drop constraint if exists program_promotions_percent_check;
alter table public.program_promotions
  add constraint program_promotions_percent_check
  check (percent_off >= 0 and percent_off <= 100 and gift_qty >= 0);

-- kind 확장: 퍼센트 할인을 1급 종류로 승격
alter table public.program_promotions
  drop constraint if exists program_promotions_kind_check;
alter table public.program_promotions
  add constraint program_promotions_kind_check
  check (kind in (
    'extra_session',
    'gift',
    'instant_discount',
    'percent_discount',
    'next_visit_credit'
  ));

comment on column public.program_promotions.scope is
  'global=샵 전체 자동 노출 / category·package=target_id 에 걸린 개별 혜택.';
comment on column public.program_promotions.percent_off is
  'Q4(a) — 정액 할인을 먼저 뺀 뒤 적용한다. list_price_krw 는 절대 갱신하지 않는다.';
comment on column public.program_promotions.last_used_at is
  'S6 — 최근 사용순 정렬용. 견적 수락 RPC 가 갱신한다.';

create index if not exists program_promotions_scope_idx
  on public.program_promotions (shop_id, scope, target_id, is_active);
create index if not exists program_promotions_recent_idx
  on public.program_promotions (shop_id, last_used_at desc nulls last);

-- ── C1 부위 taxonomy — Q6(a): 컬럼만 넣고 UI 노출은 보류 ────────────────────
alter table public.program_categories
  add column if not exists body_part text not null default 'face';

alter table public.program_categories
  drop constraint if exists program_categories_body_part_check;
alter table public.program_categories
  add constraint program_categories_body_part_check
  check (body_part in ('face', 'body', 'scalp', 'etc'));

comment on column public.program_categories.body_part is
  'Q6(a) — 데이터는 지금부터 쌓고 필터 UI 는 카테고리가 늘어난 뒤 켠다.';

-- ── E5 이탈 견적 정리 — Q5(a): 90일 보존 후 void ──────────────────────────
create index if not exists program_quotes_status_idx
  on public.program_quotes (shop_id, status, created_at desc);

create or replace function public.program_sweep_quotes(p_shop_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare v_n int;
begin
  if not public.program_shop_is_director(p_shop_id) then
    raise exception 'not director of shop' using errcode = '42501';
  end if;

  -- 당일을 넘긴 미수락 견적은 이탈로 닫는다. 삭제하지 않는다 (재상담 리드).
  update public.program_quotes
     set status = 'abandoned'
   where shop_id = p_shop_id
     and status in ('draft', 'presented')
     and created_at < date_trunc('day', now());
  get diagnostics v_n = row_count;
  return v_n;
end $$;

grant execute on function public.program_sweep_quotes(uuid) to authenticated;

comment on function public.program_sweep_quotes(uuid) is
  'Q5(a) — 이탈 견적은 90일 보존한다. 이 함수는 상태만 닫고 행은 남긴다.';

notify pgrst, 'reload schema';
