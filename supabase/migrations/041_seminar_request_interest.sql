-- 041: 수요 기반 세미나 요청 — 모든 유저 관심 표명 + shop 카운트 연동

alter table public.seminar_requests
  add column if not exists requestor_user_id uuid
    references auth.users (id) on delete set null;

alter table public.seminar_requests
  alter column requestor_shop_id drop not null;

alter table public.seminar_requests
  drop constraint if exists seminar_requests_case_id_requestor_shop_id_key;

create unique index if not exists uq_seminar_requests_case_shop
  on public.seminar_requests (case_id, requestor_shop_id)
  where requestor_shop_id is not null;

create unique index if not exists uq_seminar_requests_case_user
  on public.seminar_requests (case_id, requestor_user_id)
  where requestor_user_id is not null;

drop policy if exists "mvp_seminar_requests_update" on public.seminar_requests;
create policy "mvp_seminar_requests_update"
  on public.seminar_requests for update using (true) with check (true);

comment on column public.seminar_requests.requestor_user_id is
  '고객/원장 auth 유저 — 샵 없이도 세미나 관심(요청) 기록';

-- 관심 표명 + 작성자 샵 seminar_request_count 재집계
create or replace function public.request_seminar_interest(
  p_case_id uuid,
  p_requestor_shop_id uuid default null,
  p_requestor_user_id uuid default null
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_shop uuid;
  v_count int;
  v_exists boolean := false;
begin
  if p_case_id is null then
    raise exception 'case_id required';
  end if;
  if p_requestor_shop_id is null and p_requestor_user_id is null then
    raise exception 'requestor_shop_id or requestor_user_id required';
  end if;

  select c.shop_id into v_owner_shop
  from public.customer_charts c
  where c.id = p_case_id;

  if v_owner_shop is null then
    raise exception 'case not found';
  end if;

  if p_requestor_shop_id is not null then
    select exists (
      select 1
      from public.seminar_requests r
      where r.case_id = p_case_id
        and r.requestor_shop_id = p_requestor_shop_id
    ) into v_exists;

    if not v_exists then
      insert into public.seminar_requests (
        case_id,
        requestor_shop_id,
        requestor_user_id
      ) values (
        p_case_id,
        p_requestor_shop_id,
        p_requestor_user_id
      );
    elsif p_requestor_user_id is not null then
      update public.seminar_requests
      set requestor_user_id = coalesce(requestor_user_id, p_requestor_user_id)
      where case_id = p_case_id
        and requestor_shop_id = p_requestor_shop_id;
    end if;
  else
    select exists (
      select 1
      from public.seminar_requests r
      where r.case_id = p_case_id
        and r.requestor_user_id = p_requestor_user_id
    ) into v_exists;

    if not v_exists then
      insert into public.seminar_requests (
        case_id,
        requestor_shop_id,
        requestor_user_id
      ) values (
        p_case_id,
        null,
        p_requestor_user_id
      );
    end if;
  end if;

  if to_regprocedure('public.sync_shop_tier_metrics(uuid)') is not null then
    perform public.sync_shop_tier_metrics(v_owner_shop);
  else
    select count(*)::int into v_count
    from public.seminar_requests r
    inner join public.customer_charts c on c.id = r.case_id
    where c.shop_id = v_owner_shop;

    update public.shops
    set
      seminar_request_count = coalesce(v_count, 0),
      updated_at = now()
    where id = v_owner_shop;
  end if;

  select coalesce(seminar_request_count, 0) into v_count
  from public.shops
  where id = v_owner_shop;

  return coalesce(v_count, 0);
end;
$$;

grant execute on function public.request_seminar_interest(uuid, uuid, uuid)
  to anon, authenticated, public;

comment on function public.request_seminar_interest(uuid, uuid, uuid) is
  '세미나 관심(요청) 기록 — 결제/수강 아님. 작성자 샵 seminar_request_count 갱신';
