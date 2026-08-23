-- 053: SORI dual-track token economy — wallets, ledger, earn triggers, paywall unlock

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) Wallets + ledger (free vs paid buckets)
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.wallets (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null unique references public.shops (id) on delete cascade,
  owner_user_id uuid references public.profiles (id) on delete set null,
  free_balance int not null default 0 check (free_balance >= 0),
  paid_balance int not null default 0 check (paid_balance >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.wallets is
  'SORI 포인트 지갑 — free(활동) / paid(결제) 분리.';

comment on column public.wallets.free_balance is
  '활동 보상 적립 포인트 (환불 비대상).';
comment on column public.wallets.paid_balance is
  '인앱 결제 유료 포인트 (환불 정책 대비).';

create index if not exists idx_wallets_owner
  on public.wallets (owner_user_id)
  where owner_user_id is not null;

create table if not exists public.point_transactions (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.wallets (id) on delete cascade,
  shop_id uuid not null references public.shops (id) on delete cascade,
  amount int not null,
  bucket text not null
    check (bucket in ('free', 'paid')),
  kind text not null
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
    )),
  ref_type text not null default '',
  ref_id uuid,
  counterparty_shop_id uuid references public.shops (id) on delete set null,
  note text not null default '',
  balance_free_after int not null default 0,
  balance_paid_after int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_point_tx_shop_created
  on public.point_transactions (shop_id, created_at desc);

create index if not exists idx_point_tx_wallet_created
  on public.point_transactions (wallet_id, created_at desc);

create index if not exists idx_point_tx_ref
  on public.point_transactions (ref_type, ref_id)
  where ref_id is not null;

comment on table public.point_transactions is
  '포인트 원장 — 획득/사용/환불/수익분배 append-only.';

create table if not exists public.post_unlocks (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null
    references public.community_posts (id) on delete cascade,
  shop_id uuid not null references public.shops (id) on delete cascade,
  user_id uuid references public.profiles (id) on delete set null,
  points_spent int not null default 0 check (points_spent >= 0),
  creator_share int not null default 0 check (creator_share >= 0),
  created_at timestamptz not null default now(),
  unique (post_id, shop_id)
);

create index if not exists idx_post_unlocks_shop
  on public.post_unlocks (shop_id, created_at desc);

comment on table public.post_unlocks is
  '포인트로 잠금 해제한 게시물 접근권 — RLS/safe feed 판정에 사용.';

alter table public.wallets enable row level security;
alter table public.point_transactions enable row level security;
alter table public.post_unlocks enable row level security;

drop policy if exists "mvp_wallets_all" on public.wallets;
create policy "mvp_wallets_all"
  on public.wallets for all using (true) with check (true);

drop policy if exists "mvp_point_transactions_all" on public.point_transactions;
create policy "mvp_point_transactions_all"
  on public.point_transactions for all using (true) with check (true);

drop policy if exists "mvp_post_unlocks_all" on public.post_unlocks;
create policy "mvp_post_unlocks_all"
  on public.post_unlocks for all using (true) with check (true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) Wallet helpers + credit/debit (financial integrity)
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
  on conflict (shop_id) do update
    set updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.viewer_shop_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select s.id
  from public.shops s
  where s.owner_user_id = auth.uid()
  order by s.updated_at desc nulls last
  limit 1;
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
begin
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'credit amount must be > 0';
  end if;
  if v_bucket not in ('free', 'paid') then
    raise exception 'invalid bucket';
  end if;

  v_wallet := public.ensure_shop_wallet(p_shop_id);

  update public.wallets
  set free_balance = case when v_bucket = 'free'
        then free_balance + p_amount else free_balance end,
      paid_balance = case when v_bucket = 'paid'
        then paid_balance + p_amount else paid_balance end,
      updated_at = now()
  where id = v_wallet.id
  returning * into v_wallet;

  insert into public.point_transactions (
    wallet_id, shop_id, amount, bucket, kind,
    ref_type, ref_id, counterparty_shop_id, note,
    balance_free_after, balance_paid_after
  ) values (
    v_wallet.id, p_shop_id, p_amount, v_bucket, p_kind,
    coalesce(p_ref_type, ''), p_ref_id, p_counterparty_shop_id,
    coalesce(p_note, ''),
    v_wallet.free_balance, v_wallet.paid_balance
  )
  returning * into v_tx;

  return v_tx;
end;
$$;

-- Debit: free first, then paid (append one or two ledger rows).
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
begin
  if v_need <= 0 then
    raise exception 'debit amount must be > 0';
  end if;

  v_wallet := public.ensure_shop_wallet(p_shop_id);
  -- lock wallet row
  select * into v_wallet from public.wallets where id = v_wallet.id for update;

  v_total := v_wallet.free_balance + v_wallet.paid_balance;
  if v_total < v_need then
    raise exception 'insufficient points: have %, need %', v_total, v_need
      using errcode = 'P0001';
  end if;

  v_from_free := least(v_wallet.free_balance, v_need);
  v_from_paid := v_need - v_from_free;

  update public.wallets
  set free_balance = free_balance - v_from_free,
      paid_balance = paid_balance - v_from_paid,
      updated_at = now()
  where id = v_wallet.id
  returning * into v_wallet;

  if v_from_free > 0 then
    insert into public.point_transactions (
      wallet_id, shop_id, amount, bucket, kind,
      ref_type, ref_id, counterparty_shop_id, note,
      balance_free_after, balance_paid_after
    ) values (
      v_wallet.id, p_shop_id, -v_from_free, 'free', p_kind,
      coalesce(p_ref_type, ''), p_ref_id, p_counterparty_shop_id,
      coalesce(p_note, ''),
      v_wallet.free_balance, v_wallet.paid_balance
    )
    returning id into v_tx_id;
    v_ids := array_append(v_ids, v_tx_id);
  end if;

  if v_from_paid > 0 then
    insert into public.point_transactions (
      wallet_id, shop_id, amount, bucket, kind,
      ref_type, ref_id, counterparty_shop_id, note,
      balance_free_after, balance_paid_after
    ) values (
      v_wallet.id, p_shop_id, -v_from_paid, 'paid', p_kind,
      coalesce(p_ref_type, ''), p_ref_id, p_counterparty_shop_id,
      coalesce(p_note, ''),
      v_wallet.free_balance, v_wallet.paid_balance
    )
    returning id into v_tx_id;
    v_ids := array_append(v_ids, v_tx_id);
  end if;

  return jsonb_build_object(
    'shop_id', p_shop_id,
    'spent', v_need,
    'from_free', v_from_free,
    'from_paid', v_from_paid,
    'free_balance', v_wallet.free_balance,
    'paid_balance', v_wallet.paid_balance,
    'tx_ids', to_jsonb(v_ids)
  );
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) Visibility: unlock grants full view
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.viewer_has_post_unlock(p_post_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.post_unlocks u
    where u.post_id = p_post_id
      and u.shop_id = public.viewer_shop_id()
  );
$$;

create or replace function public.can_view_community_post_full(
  p_visibility text,
  p_shop_id uuid,
  p_author_user_id uuid,
  p_post_id uuid default null
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if coalesce(p_visibility, 'public') is distinct from 'gold_plus' then
    return true;
  end if;
  if auth.uid() is not null and p_author_user_id is not null
     and p_author_user_id = auth.uid() then
    return true;
  end if;
  if public.viewer_owns_shop(p_shop_id) then
    return true;
  end if;
  if p_post_id is not null and public.viewer_has_post_unlock(p_post_id) then
    return true;
  end if;
  return public.viewer_shop_tier_rank() >= 4;
end;
$$;

-- Refresh SELECT policies to pass post id where possible.
drop policy if exists "community_posts_select_visible" on public.community_posts;
create policy "community_posts_select_visible"
  on public.community_posts
  for select
  using (
    public.can_view_community_post_full(
      visibility, shop_id, author_user_id, id
    )
  );

drop policy if exists "post_media_select_unlocked" on public.post_media;
create policy "post_media_select_unlocked"
  on public.post_media
  for select
  using (
    exists (
      select 1
      from public.community_posts p
      where p.id = post_id
        and public.can_view_community_post_full(
          p.visibility, p.shop_id, p.author_user_id, p.id
        )
    )
  );

-- Patch safe list to include unlock-aware can_view + unlock_cost hint.
create or replace function public.list_community_posts_safe(
  p_post_type text default null,
  p_limit int default 40
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit int := greatest(1, least(coalesce(p_limit, 40), 100));
  v_result jsonb;
begin
  select coalesce(jsonb_agg(row_data order by sort_created desc), '[]'::jsonb)
  into v_result
  from (
    select
      p.created_at as sort_created,
      jsonb_build_object(
        'id', p.id,
        'shop_id', p.shop_id,
        'author_user_id', p.author_user_id,
        'post_type', p.post_type,
        'title', p.title,
        'body', case
          when public.can_view_community_post_full(
            p.visibility, p.shop_id, p.author_user_id, p.id
          ) then p.body
          else ''
        end,
        'style_tags', p.style_tags,
        'region_code', p.region_code,
        'visibility', p.visibility,
        'status', p.status,
        'like_count', p.like_count,
        'comment_count', p.comment_count,
        'save_count', p.save_count,
        'source_chart_id', p.source_chart_id,
        'created_at', p.created_at,
        'updated_at', p.updated_at,
        'is_body_locked', not public.can_view_community_post_full(
          p.visibility, p.shop_id, p.author_user_id, p.id
        ),
        'unlock_cost', 500,
        'shops', jsonb_build_object(
          'id', s.id,
          'name', s.name,
          'owner_name', s.owner_name,
          'tier_badge', s.tier_badge::text,
          'profile_image_url', s.profile_image_url
        ),
        'post_media', case
          when public.can_view_community_post_full(
            p.visibility, p.shop_id, p.author_user_id, p.id
          ) then coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'id', m.id,
                'post_id', m.post_id,
                'image_url', m.image_url,
                'sort_order', m.sort_order,
                'post_tags', coalesce((
                  select jsonb_agg(
                    jsonb_build_object(
                      'id', t.id,
                      'media_id', t.media_id,
                      'tag_kind', t.tag_kind,
                      'label', t.label,
                      'norm_x', t.norm_x,
                      'norm_y', t.norm_y,
                      'partner_id', t.partner_id,
                      'external_url', t.external_url,
                      'metadata', t.metadata
                    )
                    order by t.created_at
                  )
                  from public.post_tags t
                  where t.media_id = m.id
                ), '[]'::jsonb)
              )
              order by m.sort_order asc
            )
            from public.post_media m
            where m.post_id = p.id
          ), '[]'::jsonb)
          else '[]'::jsonb
        end,
        'device_reviews', coalesce((
          select jsonb_agg(to_jsonb(d))
          from public.device_reviews d
          where d.post_id = p.id
        ), '[]'::jsonb),
        'market_listings', coalesce((
          select jsonb_agg(to_jsonb(l))
          from public.market_listings l
          where l.post_id = p.id
        ), '[]'::jsonb)
      ) as row_data
    from public.community_posts p
    left join public.shops s on s.id = p.shop_id
    where p.status = 'published'
      and (
        p_post_type is null
        or p_post_type = ''
        or p.post_type = p_post_type
      )
    order by p.created_at desc
    limit v_limit
  ) q;

  return coalesce(v_result, '[]'::jsonb);
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) Unlock paywall + 70% creator revenue share (single transaction)
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
begin
  if p_post_id is null or p_viewer_shop_id is null then
    raise exception 'post_id and viewer_shop_id required';
  end if;

  select * into v_post
  from public.community_posts
  where id = p_post_id
  for share;

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
      p_viewer_shop_id,
      v_cost,
      'unlock_spend',
      'community_post',
      p_post_id,
      v_post.shop_id,
      'paywall unlock'
    );

    perform public.credit_points(
      v_post.shop_id,
      greatest(v_creator_share, 0),
      'free',
      'unlock_revenue',
      'community_post',
      p_post_id,
      p_viewer_shop_id,
      'creator share ' || v_share_pct::text || '%'
    );

    insert into public.post_unlocks (
      post_id, shop_id, user_id, points_spent, creator_share
    ) values (
      p_post_id,
      p_viewer_shop_id,
      auth.uid(),
      v_cost,
      v_creator_share
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
  '포인트 차감 + 작성자 70% 수익분배 + post_unlocks 원자 처리.';

-- ═══════════════════════════════════════════════════════════════════════════
-- 5) Activity earn triggers + purchase stub
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.earn_points_on_community_content()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_table_name = 'community_posts' then
    if new.status = 'published' and new.shop_id is not null then
      if new.post_type = 'case_share' then
        perform public.credit_points(
          new.shop_id, 100, 'free', 'earn_case_share',
          'community_post', new.id, null, '임상 케이스 공유 보상'
        );
      elsif new.post_type in ('device_review', 'interior') then
        perform public.credit_points(
          new.shop_id, 80, 'free', 'earn_review',
          'community_post', new.id, null, '커뮤니티 콘텐츠 보상'
        );
      end if;
    end if;
  elsif tg_table_name = 'device_reviews' then
    update public.shops s
    set updated_at = now()
    from public.community_posts p
    where p.id = new.post_id and s.id = p.shop_id;
    -- device_reviews usually accompany community_posts; skip double-credit
  elsif tg_table_name = 'community_comments' then
    if new.status = 'published' and new.author_shop_id is not null then
      perform public.credit_points(
        new.author_shop_id, 10, 'free', 'earn_comment',
        'community_comment', new.id, null, '댓글 참여 보상'
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_earn_points_community_posts on public.community_posts;
create trigger trg_earn_points_community_posts
  after insert on public.community_posts
  for each row execute function public.earn_points_on_community_content();

drop trigger if exists trg_earn_points_community_comments on public.community_comments;
create trigger trg_earn_points_community_comments
  after insert on public.community_comments
  for each row execute function public.earn_points_on_community_content();

-- Best comment selection (manual / admin).
create or replace function public.mark_best_community_comment(
  p_comment_id uuid,
  p_bonus int default 200
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_c public.community_comments%rowtype;
  v_bonus int := greatest(coalesce(p_bonus, 200), 1);
begin
  select * into v_c from public.community_comments where id = p_comment_id;
  if not found then
    raise exception 'comment not found';
  end if;
  if v_c.author_shop_id is null then
    raise exception 'comment has no author shop';
  end if;

  perform public.credit_points(
    v_c.author_shop_id, v_bonus, 'free', 'earn_best_comment',
    'community_comment', p_comment_id, null, '베스트 댓글 보상'
  );

  return jsonb_build_object(
    'ok', true,
    'comment_id', p_comment_id,
    'shop_id', v_c.author_shop_id,
    'bonus', v_bonus
  );
end;
$$;

-- IAP bridge stub — credits paid bucket (client calls after store receipt verify later).
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
    p_shop_id,
    v_amount,
    'paid',
    'purchase',
    'iap_order',
    null,
    null,
    coalesce(nullif(trim(p_order_ref), ''), p_sku)
  );
  v_wallet := public.ensure_shop_wallet(p_shop_id);

  return jsonb_build_object(
    'ok', true,
    'shop_id', p_shop_id,
    'credited', v_amount,
    'sku', p_sku,
    'order_ref', p_order_ref,
    'free_balance', v_wallet.free_balance,
    'paid_balance', (
      select paid_balance from public.wallets where shop_id = p_shop_id
    ),
    'tx_id', v_tx.id
  );
end;
$$;

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
    'free_balance', v_w.free_balance,
    'paid_balance', v_w.paid_balance,
    'total_balance', v_w.free_balance + v_w.paid_balance,
    'updated_at', v_w.updated_at
  );
end;
$$;

-- Backfill wallets for existing shops (0 balance).
insert into public.wallets (shop_id, owner_user_id)
select s.id, s.owner_user_id
from public.shops s
on conflict (shop_id) do nothing;

grant execute on function public.ensure_shop_wallet(uuid) to anon, authenticated, public;
grant execute on function public.viewer_shop_id() to anon, authenticated, public;
grant execute on function public.viewer_has_post_unlock(uuid) to anon, authenticated, public;
grant execute on function public.credit_points(uuid, int, text, text, text, uuid, uuid, text)
  to anon, authenticated, public;
grant execute on function public.debit_points(uuid, int, text, text, uuid, uuid, text)
  to anon, authenticated, public;
grant execute on function public.unlock_community_post_with_points(uuid, uuid, int, int)
  to anon, authenticated, public;
grant execute on function public.mark_best_community_comment(uuid, int)
  to anon, authenticated, public;
grant execute on function public.purchase_sori_points(uuid, int, text, text)
  to anon, authenticated, public;
grant execute on function public.get_shop_wallet(uuid)
  to anon, authenticated, public;
grant execute on function public.can_view_community_post_full(text, uuid, uuid, uuid)
  to anon, authenticated, public;
grant execute on function public.list_community_posts_safe(text, int)
  to anon, authenticated, public;
