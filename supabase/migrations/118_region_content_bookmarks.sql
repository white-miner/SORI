-- 118: Expand — region map 저장함 SSOT (community post + seminar)
-- Contract: toggle/list only. No GPS history. No chart/Visit bookmarks here.

create table if not exists public.region_content_bookmarks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in ('post', 'seminar')),
  target_id uuid not null,
  created_at timestamptz not null default now(),
  unique (user_id, kind, target_id)
);

create index if not exists idx_region_content_bookmarks_user
  on public.region_content_bookmarks (user_id, created_at desc);

comment on table public.region_content_bookmarks is
  'User-scoped saved community posts/seminars for region map 저장함 (C.2).';

alter table public.region_content_bookmarks enable row level security;

drop policy if exists "mvp_region_content_bookmarks_all" on public.region_content_bookmarks;
create policy "mvp_region_content_bookmarks_all"
  on public.region_content_bookmarks for all using (true) with check (true);

create or replace function public.toggle_region_content_bookmark(
  p_kind text,
  p_target_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_kind text := lower(trim(coalesce(p_kind, '')));
  v_bookmarked boolean;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if v_kind not in ('post', 'seminar') then
    raise exception 'kind must be post or seminar';
  end if;
  if p_target_id is null then
    raise exception 'target_id required';
  end if;

  if v_kind = 'post' and not exists (
    select 1 from public.community_posts where id = p_target_id
  ) then
    raise exception 'post not found';
  end if;
  if v_kind = 'seminar' and not exists (
    select 1 from public.seminar_classes where id = p_target_id
  ) then
    raise exception 'seminar not found';
  end if;

  if exists (
    select 1 from public.region_content_bookmarks
    where user_id = v_uid and kind = v_kind and target_id = p_target_id
  ) then
    delete from public.region_content_bookmarks
    where user_id = v_uid and kind = v_kind and target_id = p_target_id;
    v_bookmarked := false;
  else
    insert into public.region_content_bookmarks (user_id, kind, target_id)
    values (v_uid, v_kind, p_target_id)
    on conflict (user_id, kind, target_id) do nothing;
    v_bookmarked := true;
  end if;

  return jsonb_build_object(
    'ok', true,
    'kind', v_kind,
    'target_id', p_target_id,
    'bookmarked', v_bookmarked
  );
end;
$$;

grant execute on function public.toggle_region_content_bookmark(text, uuid)
  to authenticated;

create or replace function public.list_my_region_content_bookmarks(
  p_limit int default 200
)
returns table (
  kind text,
  target_id uuid,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_limit int := least(greatest(coalesce(p_limit, 200), 1), 500);
begin
  if v_uid is null then
    return;
  end if;
  return query
    select b.kind, b.target_id, b.created_at
    from public.region_content_bookmarks b
    where b.user_id = v_uid
    order by b.created_at desc
    limit v_limit;
end;
$$;

grant execute on function public.list_my_region_content_bookmarks(int)
  to authenticated;
