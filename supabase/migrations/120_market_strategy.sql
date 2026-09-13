-- 120: Expand — 상권·목표매출 전략 저장 (샵 격리)
-- Contract: planner / candidates / actions JSON payload. No payment tables.

create table if not exists public.market_strategy_states (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, user_id)
);

create index if not exists idx_market_strategy_states_shop
  on public.market_strategy_states (shop_id, updated_at desc);

comment on table public.market_strategy_states is
  'Per-shop owner market strategy planner, candidates, diagnosis metrics, action plans.';

alter table public.market_strategy_states enable row level security;

drop policy if exists "market_strategy_states_owner" on public.market_strategy_states;
create policy "market_strategy_states_owner"
  on public.market_strategy_states
  for all
  using (
    user_id = auth.uid()
    and exists (
      select 1
      from public.shops s
      where s.id = shop_id
        and s.owner_user_id = auth.uid()
    )
  )
  with check (
    user_id = auth.uid()
    and exists (
      select 1
      from public.shops s
      where s.id = shop_id
        and s.owner_user_id = auth.uid()
    )
  );
