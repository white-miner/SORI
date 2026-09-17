-- 054: Dual-currency — point_* (non-withdrawable) vs settlement_* (withdrawable KRW)

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) Wallets: rename point columns + add settlement axis
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.wallets
  add column if not exists point_free_balance int,
  add column if not exists point_paid_balance int,
  add column if not exists settlement_balance int not null default 0,
  add column if not exists settlement_pending int not null default 0,
  add column if not exists settlement_paid_lifetime int not null default 0;

-- Migrate 053 free/paid → point_*
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'wallets'
      and column_name = 'free_balance'
  ) then
    update public.wallets
    set point_free_balance = coalesce(point_free_balance, free_balance),
        point_paid_balance = coalesce(point_paid_balance, paid_balance)
    where point_free_balance is null or point_paid_balance is null;
  end if;
end $$;

update public.wallets
set point_free_balance = coalesce(point_free_balance, 0),
    point_paid_balance = coalesce(point_paid_balance, 0);

alter table public.wallets
  alter column point_free_balance set default 0,
  alter column point_paid_balance set default 0;

alter table public.wallets
  alter column point_free_balance set not null,
  alter column point_paid_balance set not null;

-- Drop legacy columns if present (after copy)
alter table public.wallets drop column if exists free_balance;
alter table public.wallets drop column if exists paid_balance;

alter table public.wallets drop constraint if exists wallets_point_free_balance_check;
alter table public.wallets drop constraint if exists wallets_point_paid_balance_check;
alter table public.wallets drop constraint if exists wallets_settlement_balance_check;
alter table public.wallets
  add constraint wallets_point_free_balance_check check (point_free_balance >= 0),
  add constraint wallets_point_paid_balance_check check (point_paid_balance >= 0),
  add constraint wallets_settlement_balance_check check (settlement_balance >= 0),
  add constraint wallets_settlement_pending_check check (settlement_pending >= 0);

comment on column public.wallets.point_free_balance is
  'SORI 포인트(활동) — 출금 불가, 인앱 소비만.';
comment on column public.wallets.point_paid_balance is
  'SORI 포인트(유료 충전) — 출금 불가, 인앱 소비만.';
comment on column public.wallets.settlement_balance is
  'SORI 정산금(KRW) — 출금 가능 현금성 잔액.';
comment on column public.wallets.settlement_pending is
  '출금 요청 대기 중 금액(KRW).';
comment on column public.wallets.settlement_paid_lifetime is
  '누적 환전 완료 금액(KRW).';

-- Backfill settlement from shops.sori_cash_balance (seminar legacy)
update public.wallets w
set settlement_balance = greatest(coalesce(s.sori_cash_balance, 0), 0),
    updated_at = now()
from public.shops s
where w.shop_id = s.id
  and coalesce(s.sori_cash_balance, 0) > coalesce(w.settlement_balance, 0);

-- point_transactions: rename after-balance columns
alter table public.point_transactions
  add column if not exists balance_point_free_after int,
  add column if not exists balance_point_paid_after int;

update public.point_transactions
set balance_point_free_after = coalesce(balance_point_free_after, balance_free_after, 0),
    balance_point_paid_after = coalesce(balance_point_paid_after, balance_paid_after, 0);

alter table public.point_transactions
  alter column balance_point_free_after set default 0,
  alter column balance_point_paid_after set default 0;

update public.point_transactions
set balance_point_free_after = coalesce(balance_point_free_after, 0),
    balance_point_paid_after = coalesce(balance_point_paid_after, 0);

alter table public.point_transactions
  alter column balance_point_free_after set not null,
  alter column balance_point_paid_after set not null;

alter table public.point_transactions drop column if exists balance_free_after;
alter table public.point_transactions drop column if exists balance_paid_after;

-- Harden point kinds: never allow withdraw/payout on point ledger
alter table public.point_transactions
  drop constraint if exists point_transactions_kind_check;

alter table public.point_transactions
  add constraint point_transactions_kind_check
  check (kind in (
    'earn_review',
    'earn_case_share',
    'earn_comment',
    'earn_best_comment',
    'purchase',
    'unlock_spend',
    'unlock_revenue',
    'refund',
    'adjust'
  ));

comment on table public.point_transactions is
  '포인트 원장 전용 — 출금/정산 kind 금지.';

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) Settlement ledger (KRW only)
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.settlement_transactions (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.wallets (id) on delete cascade,
  shop_id uuid not null references public.shops (id) on delete cascade,
  amount int not null,
  kind text not null
    check (kind in (
      'market_sale',
      'affiliate_payout',
      'seminar_settle',
      'withdraw_request',
      'withdraw_paid',
      'withdraw_reject',
      'withhold_tax',
      'adjust'
    )),
  status text not null default 'posted'
    check (status in ('posted', 'pending', 'paid', 'rejected', 'void')),
  ref_type text not null default '',
  ref_id uuid,
  note text not null default '',
  balance_after int not null default 0,
  bank_account_mask text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_settlement_tx_shop_created
  on public.settlement_transactions (shop_id, created_at desc);

create index if not exists idx_settlement_tx_status
  on public.settlement_transactions (status, created_at desc)
  where status = 'pending';

comment on table public.settlement_transactions is
  '정산금(KRW) 원장 — 포인트와 물리·논리 격리. 환전 게이트웨이 SSOT.';

alter table public.settlement_transactions enable row level security;
drop policy if exists "mvp_settlement_transactions_all" on public.settlement_transactions;
create policy "mvp_settlement_transactions_all"
  on public.settlement_transactions for all using (true) with check (true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) Point helpers rewritten onto point_* columns
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.ensure_shop_wallet(p_shop_id uuid)
returns public.wallets
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.wallets%rowtype;
  v_owner uuid;
begin
  if p_shop_id is null then
    raise exception 'shop_id required';
  end if;

  select * into v_row from public.wallets where shop_id = p_shop_id;
  if found then
    return v_row;
  end if;

  select owner_user_id into v_owner from public.shops where id = p_shop_id;

  insert into public.wallets (shop_id, owner_user_id)
  values (p_shop_id, v_owner)
  on conflict (shop_id) do update set updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.credit_points(
  p_shop_id uuid,
  p_amount int,
  p_bucket text,
  p_kind text,
  p_ref_type text default '',
  p_ref_id uuid default null,
  p_counterparty_shop_id uuid default null,
  p_note text default ''
)
returns public.point_transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet public.wallets%rowtype;
  v_tx public.point_transactions%rowtype;
  v_bucket text := lower(trim(coalesce(p_bucket, 'free')));
  v_kind text := lower(trim(coalesce(p_kind, '')));
begin
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'credit amount must be > 0';
  end if;
  if v_bucket not in ('free', 'paid') then
    raise exception 'invalid point bucket';
  end if;
  -- Hard lock: never credit settlement via point RPC
  if v_kind in ('withdraw', 'withdraw_request', 'withdraw_paid', 'market_sale',
                'affiliate_payout', 'seminar_settle', 'payout') then
    raise exception 'kind % forbidden on point ledger', v_kind;
  end if;

  v_wallet := public.ensure_shop_wallet(p_shop_id);

  update public.wallets
  set point_free_balance = case when v_bucket = 'free'
        then point_free_balance + p_amount else point_free_balance end,
      point_paid_balance = case when v_bucket = 'paid'
        then point_paid_balance + p_amount else point_paid_balance end,
      updated_at = now()
  where id = v_wallet.id
  returning * into v_wallet;

  insert into public.point_transactions (
    wallet_id, shop_id, amount, bucket, kind,
    ref_type, ref_id, counterparty_shop_id, note,
    balance_point_free_after, balance_point_paid_after
  ) values (
    v_wallet.id, p_shop_id, p_amount, v_bucket, p_kind,
    coalesce(p_ref_type, ''), p_ref_id, p_counterparty_shop_id,
    coalesce(p_note, ''),
    v_wallet.point_free_balance, v_wallet.point_paid_balance
  )
  returning * into v_tx;

  return v_tx;
end;
$$;

create or replace function public.debit_points(
  p_shop_id uuid,
  p_amount int,
  p_kind text,
  p_ref_type text default '',
  p_ref_id uuid default null,
  p_counterparty_shop_id uuid default null,
  p_note text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet public.wallets%rowtype;
  v_need int := coalesce(p_amount, 0);
  v_from_free int := 0;
  v_from_paid int := 0;
  v_total int;
  v_ids uuid[] := '{}';
  v_tx_id uuid;
  v_kind text := lower(trim(coalesce(p_kind, '')));
begin
  if v_need <= 0 then
    raise exception 'debit amount must be > 0';
  end if;
  if v_kind like 'withdraw%' or v_kind in ('market_sale', 'affiliate_payout', 'seminar_settle') then
    raise exception 'kind % forbidden on point ledger — use settlement RPC', v_kind;
  end if;

  v_wallet := public.ensure_shop_wallet(p_shop_id);
  select * into v_wallet from public.wallets where id = v_wallet.id for update;

  v_total := v_wallet.point_free_balance + v_wallet.point_paid_balance;
  if v_total < v_need then
    raise exception 'insufficient points: have %, need %', v_total, v_need
      using errcode = 'P0001';
  end if;

  v_from_free := least(v_wallet.point_free_balance, v_need);
  v_from_paid := v_need - v_from_free;

  update public.wallets
  set point_free_balance = point_free_balance - v_from_free,
      point_paid_balance = point_paid_balance - v_from_paid,
      updated_at = now()
  where id = v_wallet.id
  returning * into v_wallet;

  if v_from_free > 0 then
    insert into public.point_transactions (
      wallet_id, shop_id, amount, bucket, kind,
      ref_type, ref_id, counterparty_shop_id, note,
      balance_point_free_after, balance_point_paid_after
    ) values (
      v_wallet.id, p_shop_id, -v_from_free, 'free', p_kind,
      coalesce(p_ref_type, ''), p_ref_id, p_counterparty_shop_id,
      coalesce(p_note, ''),
      v_wallet.point_free_balance, v_wallet.point_paid_balance
    )
    returning id into v_tx_id;
    v_ids := array_append(v_ids, v_tx_id);
  end if;

  if v_from_paid > 0 then
    insert into public.point_transactions (
      wallet_id, shop_id, amount, bucket, kind,
      ref_type, ref_id, counterparty_shop_id, note,
      balance_point_free_after, balance_point_paid_after
    ) values (
      v_wallet.id, p_shop_id, -v_from_paid, 'paid', p_kind,
      coalesce(p_ref_type, ''), p_ref_id, p_counterparty_shop_id,
      coalesce(p_note, ''),
      v_wallet.point_free_balance, v_wallet.point_paid_balance
    )
    returning id into v_tx_id;
    v_ids := array_append(v_ids, v_tx_id);
  end if;

  return jsonb_build_object(
    'shop_id', p_shop_id,
    'spent', v_need,
    'from_free', v_from_free,
    'from_paid', v_from_paid,
    'point_free_balance', v_wallet.point_free_balance,
    'point_paid_balance', v_wallet.point_paid_balance,
    'tx_ids', to_jsonb(v_ids)
  );
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) Settlement credit/debit + withdraw gateway (settlement_balance ONLY)
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.credit_settlement(
  p_shop_id uuid,
  p_amount int,
  p_kind text,
  p_ref_type text default '',
  p_ref_id uuid default null,
  p_note text default ''
)
returns public.settlement_transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet public.wallets%rowtype;
  v_tx public.settlement_transactions%rowtype;
  v_kind text := lower(trim(coalesce(p_kind, '')));
begin
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'settlement credit must be > 0';
  end if;
  if v_kind not in (
    'market_sale', 'affiliate_payout', 'seminar_settle',
    'withdraw_reject', 'adjust'
  ) then
    raise exception 'kind % not allowed on settlement credit', v_kind;
  end if;

  v_wallet := public.ensure_shop_wallet(p_shop_id);
  select * into v_wallet from public.wallets where id = v_wallet.id for update;

  update public.wallets
  set settlement_balance = settlement_balance + p_amount,
      updated_at = now()
  where id = v_wallet.id
  returning * into v_wallet;

  -- Keep legacy column roughly in sync for seminar UI
  update public.shops
  set sori_cash_balance = v_wallet.settlement_balance,
      updated_at = now()
  where id = p_shop_id;

  insert into public.settlement_transactions (
    wallet_id, shop_id, amount, kind, status,
    ref_type, ref_id, note, balance_after
  ) values (
    v_wallet.id, p_shop_id, p_amount, v_kind, 'posted',
    coalesce(p_ref_type, ''), p_ref_id, coalesce(p_note, ''),
    v_wallet.settlement_balance
  )
  returning * into v_tx;

  return v_tx;
end;
$$;

create or replace function public.request_settlement_withdraw(
  p_shop_id uuid,
  p_amount int,
  p_bank_account_mask text default '',
  p_note text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet public.wallets%rowtype;
  v_tx public.settlement_transactions%rowtype;
  v_amount int := coalesce(p_amount, 0);
begin
  if v_amount <= 0 then
    raise exception 'withdraw amount must be > 0';
  end if;

  v_wallet := public.ensure_shop_wallet(p_shop_id);
  -- Lock and read ONLY settlement_balance (never touch point_*)
  select * into v_wallet from public.wallets where id = v_wallet.id for update;

  if v_wallet.settlement_balance < v_amount then
    raise exception 'insufficient settlement: have %, need %',
      v_wallet.settlement_balance, v_amount
      using errcode = 'P0001';
  end if;

  update public.wallets
  set settlement_balance = settlement_balance - v_amount,
      settlement_pending = settlement_pending + v_amount,
      updated_at = now()
  where id = v_wallet.id
  returning * into v_wallet;

  update public.shops
  set sori_cash_balance = v_wallet.settlement_balance,
      updated_at = now()
  where id = p_shop_id;

  insert into public.settlement_transactions (
    wallet_id, shop_id, amount, kind, status,
    ref_type, note, balance_after, bank_account_mask
  ) values (
    v_wallet.id, p_shop_id, -v_amount, 'withdraw_request', 'pending',
    'withdraw', coalesce(p_note, '계좌 환전 요청'),
    v_wallet.settlement_balance,
    coalesce(p_bank_account_mask, '')
  )
  returning * into v_tx;

  return jsonb_build_object(
    'ok', true,
    'shop_id', p_shop_id,
    'amount', v_amount,
    'settlement_balance', v_wallet.settlement_balance,
    'settlement_pending', v_wallet.settlement_pending,
    'point_free_balance', v_wallet.point_free_balance,
    'point_paid_balance', v_wallet.point_paid_balance,
    'tx_id', v_tx.id,
    'status', 'pending'
  );
end;
$$;

comment on function public.request_settlement_withdraw(uuid, int, text, text) is
  '환전 게이트웨이 — settlement_balance만 차감. 포인트 컬럼 참조/차감 금지.';

-- Mark pending withdraw as paid (admin)
create or replace function public.complete_settlement_withdraw(
  p_tx_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tx public.settlement_transactions%rowtype;
  v_wallet public.wallets%rowtype;
  v_amt int;
begin
  select * into v_tx from public.settlement_transactions
  where id = p_tx_id for update;
  if not found then
    raise exception 'settlement tx not found';
  end if;
  if v_tx.kind is distinct from 'withdraw_request' or v_tx.status is distinct from 'pending' then
    raise exception 'tx not a pending withdraw';
  end if;

  v_amt := abs(v_tx.amount);

  select * into v_wallet from public.wallets where shop_id = v_tx.shop_id for update;

  update public.wallets
  set settlement_pending = greatest(settlement_pending - v_amt, 0),
      settlement_paid_lifetime = settlement_paid_lifetime + v_amt,
      updated_at = now()
  where id = v_wallet.id
  returning * into v_wallet;

  update public.settlement_transactions
  set status = 'paid',
      kind = 'withdraw_paid',
      updated_at = now(),
      balance_after = v_wallet.settlement_balance
  where id = p_tx_id
  returning * into v_tx;

  return to_jsonb(v_tx);
end;
$$;

-- When affiliate commission becomes paid → credit settlement
create or replace function public.sync_affiliate_paid_to_settlement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE'
     and old.status is distinct from 'paid'
     and new.status = 'paid'
     and coalesce(new.amount, 0) > 0 then
    perform public.credit_settlement(
      new.shop_id,
      new.amount,
      'affiliate_payout',
      'affiliate_commission',
      new.id,
      '제휴 수수료 정산 입금'
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_affiliate_paid_to_settlement on public.affiliate_commissions;
create trigger trg_affiliate_paid_to_settlement
  after update of status on public.affiliate_commissions
  for each row execute function public.sync_affiliate_paid_to_settlement();

-- ═══════════════════════════════════════════════════════════════════════════
-- 5) Unlock: creator share MUST stay as non-withdrawable points
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.unlock_community_post_with_points(
  p_post_id uuid,
  p_viewer_shop_id uuid,
  p_cost int default 500,
  p_creator_share_pct int default 70
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post public.community_posts%rowtype;
  v_cost int := greatest(coalesce(p_cost, 500), 1);
  v_share_pct int := greatest(least(coalesce(p_creator_share_pct, 70), 100), 0);
  v_creator_share int;
  v_debit jsonb;
  v_media jsonb;
  v_unlocked boolean;
  v_creator_tx public.point_transactions%rowtype;
begin
  if p_post_id is null or p_viewer_shop_id is null then
    raise exception 'post_id and viewer_shop_id required';
  end if;

  select * into v_post from public.community_posts where id = p_post_id for share;
  if not found then
    raise exception 'post not found';
  end if;
  if v_post.shop_id = p_viewer_shop_id then
    raise exception 'cannot unlock own post';
  end if;

  if exists (
    select 1 from public.post_unlocks
    where post_id = p_post_id and shop_id = p_viewer_shop_id
  ) then
    v_unlocked := true;
  elsif public.can_view_community_post_full(
    v_post.visibility, v_post.shop_id, v_post.author_user_id, v_post.id
  ) then
    v_unlocked := true;
  else
    v_unlocked := false;
  end if;

  if not v_unlocked then
    v_creator_share := (v_cost * v_share_pct) / 100;

    v_debit := public.debit_points(
      p_viewer_shop_id, v_cost, 'unlock_spend',
      'community_post', p_post_id, v_post.shop_id, 'paywall unlock'
    );

    -- STRICT: creator share → point_free only (never settlement / KRW)
    v_creator_tx := public.credit_points(
      v_post.shop_id,
      greatest(v_creator_share, 0),
      'free',
      'unlock_revenue',
      'community_post',
      p_post_id,
      p_viewer_shop_id,
      '창작 포인트(출금불가) ' || v_share_pct::text || '%'
    );

    if v_creator_tx.bucket is distinct from 'free'
       or v_creator_tx.kind is distinct from 'unlock_revenue' then
      raise exception 'creator share must remain non-withdrawable points';
    end if;

    insert into public.post_unlocks (
      post_id, shop_id, user_id, points_spent, creator_share
    ) values (
      p_post_id, p_viewer_shop_id, auth.uid(), v_cost, v_creator_share
    )
    on conflict (post_id, shop_id) do nothing;
  else
    v_creator_share := 0;
    v_debit := '{}'::jsonb;
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', m.id,
      'post_id', m.post_id,
      'image_url', m.image_url,
      'sort_order', m.sort_order
    )
    order by m.sort_order
  ), '[]'::jsonb)
  into v_media
  from public.post_media m
  where m.post_id = p_post_id;

  return jsonb_build_object(
    'ok', true,
    'already_unlocked', v_unlocked,
    'points_spent', case when v_unlocked then 0 else v_cost end,
    'creator_share', v_creator_share,
    'creator_currency', 'point',
    'debit', v_debit,
    'post', jsonb_build_object(
      'id', v_post.id,
      'shop_id', v_post.shop_id,
      'author_user_id', v_post.author_user_id,
      'post_type', v_post.post_type,
      'title', v_post.title,
      'body', v_post.body,
      'style_tags', v_post.style_tags,
      'visibility', v_post.visibility,
      'status', v_post.status,
      'like_count', v_post.like_count,
      'comment_count', v_post.comment_count,
      'save_count', v_post.save_count,
      'source_chart_id', v_post.source_chart_id,
      'created_at', v_post.created_at,
      'is_body_locked', false,
      'unlock_cost', v_cost,
      'post_media', v_media
    )
  );
end;
$$;

comment on function public.unlock_community_post_with_points(uuid, uuid, int, int) is
  '페이월: 작성자 70%는 출금불가 포인트만. settlement 경로 차단.';

-- Wallet snapshot for FE (no combined "total assets")
create or replace function public.get_shop_wallet(p_shop_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_w public.wallets%rowtype;
begin
  v_w := public.ensure_shop_wallet(p_shop_id);
  select * into v_w from public.wallets where shop_id = p_shop_id;
  return jsonb_build_object(
    'id', v_w.id,
    'shop_id', v_w.shop_id,
    'owner_user_id', v_w.owner_user_id,
    'point_free_balance', v_w.point_free_balance,
    'point_paid_balance', v_w.point_paid_balance,
    'point_total', v_w.point_free_balance + v_w.point_paid_balance,
    'settlement_balance', v_w.settlement_balance,
    'settlement_pending', v_w.settlement_pending,
    'settlement_paid_lifetime', v_w.settlement_paid_lifetime,
    -- legacy aliases for older clients (points only)
    'free_balance', v_w.point_free_balance,
    'paid_balance', v_w.point_paid_balance,
    'updated_at', v_w.updated_at
  );
end;
$$;

create or replace function public.purchase_sori_points(
  p_shop_id uuid,
  p_amount int,
  p_sku text default 'sori_points_pack',
  p_order_ref text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_amount int := coalesce(p_amount, 0);
  v_tx public.point_transactions%rowtype;
  v_wallet public.wallets%rowtype;
begin
  if v_amount <= 0 then
    raise exception 'purchase amount must be > 0';
  end if;

  v_tx := public.credit_points(
    p_shop_id, v_amount, 'paid', 'purchase',
    'iap_order', null, null,
    coalesce(nullif(trim(p_order_ref), ''), p_sku)
  );
  select * into v_wallet from public.wallets where shop_id = p_shop_id;

  return jsonb_build_object(
    'ok', true,
    'shop_id', p_shop_id,
    'credited', v_amount,
    'sku', p_sku,
    'currency', 'point',
    'point_free_balance', v_wallet.point_free_balance,
    'point_paid_balance', v_wallet.point_paid_balance,
    'settlement_balance', v_wallet.settlement_balance,
    'tx_id', v_tx.id
  );
end;
$$;

grant execute on function public.credit_settlement(uuid, int, text, text, uuid, text)
  to anon, authenticated, public;
grant execute on function public.request_settlement_withdraw(uuid, int, text, text)
  to anon, authenticated, public;
grant execute on function public.complete_settlement_withdraw(uuid)
  to anon, authenticated, public;
grant execute on function public.credit_points(uuid, int, text, text, text, uuid, uuid, text)
  to anon, authenticated, public;
grant execute on function public.debit_points(uuid, int, text, text, uuid, uuid, text)
  to anon, authenticated, public;
grant execute on function public.unlock_community_post_with_points(uuid, uuid, int, int)
  to anon, authenticated, public;
grant execute on function public.get_shop_wallet(uuid)
  to anon, authenticated, public;
grant execute on function public.purchase_sori_points(uuid, int, text, text)
  to anon, authenticated, public;
