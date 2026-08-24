-- 067_review_ops_publish_status.sql
-- Review ops P2: Naver publish status machine + review request alimtalk template note.

alter table public.customer_reviews
  add column if not exists naver_publish_status text not null default 'none';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'customer_reviews_naver_publish_status_check'
  ) then
    alter table public.customer_reviews
      add constraint customer_reviews_naver_publish_status_check
      check (
        naver_publish_status in ('none', 'copied', 'registered', 'confirmed')
      );
  end if;
end $$;

-- Backfill from legacy boolean.
update public.customer_reviews
set naver_publish_status = 'registered'
where coalesce(naver_registered, false) = true
  and naver_publish_status = 'none';

comment on column public.customer_reviews.naver_publish_status is
  'Review ops publish ladder: none → copied → registered → confirmed.';

-- Optional helper for directors to bump status without full row replace.
create or replace function public.set_review_naver_publish_status(
  p_review_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_status text := lower(trim(coalesce(p_status, 'none')));
  v_row public.customer_reviews%rowtype;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if v_status not in ('none', 'copied', 'registered', 'confirmed') then
    raise exception 'invalid status';
  end if;

  update public.customer_reviews r
  set
    naver_publish_status = v_status,
    naver_registered = (v_status in ('registered', 'confirmed')),
    naver_registered_at = case
      when v_status in ('registered', 'confirmed')
        then coalesce(r.naver_registered_at, now())
      else r.naver_registered_at
    end,
    updated_at = now()
  where r.id = p_review_id
    and exists (
      select 1 from public.shops s
      where s.id = r.shop_id
        and (
          s.owner_user_id = v_uid
          or exists (
            select 1 from public.shop_memberships m
            where m.shop_id = s.id and m.user_id = v_uid
          )
        )
    )
  returning * into v_row;

  if v_row.id is null then
    raise exception 'review not found or access denied';
  end if;
  return to_jsonb(v_row);
end;
$$;

grant execute on function public.set_review_naver_publish_status(uuid, text)
  to authenticated;
