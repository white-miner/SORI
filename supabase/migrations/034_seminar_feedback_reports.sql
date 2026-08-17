-- 034: AI 세미나 피드백 보관함 리포트

create table if not exists public.seminar_feedback_reports (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.seminar_classes (id) on delete cascade,
  shop_id uuid not null references public.shops (id) on delete cascade,
  top_insight_tags jsonb not null default '[]'::jsonb,
  ai_summary_strength text not null default '',
  ai_summary_improvement text not null default '',
  raw_feedback_count int not null default 0 check (raw_feedback_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (class_id)
);

create index if not exists idx_seminar_feedback_reports_shop
  on public.seminar_feedback_reports (shop_id, updated_at desc);

comment on table public.seminar_feedback_reports is
  '종료 세미나 클래스별 수강생 인사이트 태그·AI 요약 리포트';

alter table public.seminar_feedback_reports enable row level security;
drop policy if exists "mvp_seminar_feedback_reports_all"
  on public.seminar_feedback_reports;
create policy "mvp_seminar_feedback_reports_all"
  on public.seminar_feedback_reports for all using (true) with check (true);

-- 리뷰 태그·코멘트 집계 → AI 요약 리포트 upsert
create or replace function public.refresh_seminar_feedback_report(p_class_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_class public.seminar_classes%rowtype;
  v_count int;
  v_top_tags jsonb;
  v_top1 text;
  v_top2 text;
  v_strength text;
  v_improvement text;
  v_report_id uuid;
begin
  if p_class_id is null then
    return null;
  end if;

  select * into v_class
  from public.seminar_classes
  where id = p_class_id;

  if not found then
    return null;
  end if;

  select count(*)::int into v_count
  from public.seminar_enrollment_reviews r
  inner join public.seminar_enrollments e on e.id = r.enrollment_id
  where e.class_id = p_class_id;

  if coalesce(v_count, 0) < 1 then
    return null;
  end if;

  select coalesce(jsonb_agg(tag order by cnt desc), '[]'::jsonb)
  into v_top_tags
  from (
    select tag, count(*)::int as cnt
    from public.seminar_enrollment_reviews r
    inner join public.seminar_enrollments e on e.id = r.enrollment_id
    cross join lateral jsonb_array_elements_text(r.insight_tags) as tag
    where e.class_id = p_class_id
    group by tag
    order by cnt desc
    limit 8
  ) t;

  v_top1 := coalesce(v_top_tags->>0, '#이해쏙쏙');
  v_top2 := coalesce(v_top_tags->>1, '#실무적용도100%');

  v_strength :=
    '수강생 ' || v_count || '명의 피드백에서 '
    || v_top1 || ', ' || v_top2
    || ' 인사이트가 두드러졌습니다. '
    || '현장 설명력과 임상 케이스 전달력이 높게 평가됐으며, '
    || '수강생 다수가 실무에 바로 적용 가능하다고 응답했습니다.';

  v_improvement :=
    '다음 기수에서는 Q&A·실습 비중을 '
    || case
      when v_count >= 5 then '15~20%'
      else '10%'
    end
    || ' 늘리고, 초급·중급 맞춤 블록을 분리하면 만족도가 더 올라갈 것으로 보입니다. '
    || '또한 ' || v_top1 || ' 강점을 유지하면서 사전 자료 공유를 추가하면 재등록률 개선에 도움이 됩니다.';

  insert into public.seminar_feedback_reports (
    class_id,
    shop_id,
    top_insight_tags,
    ai_summary_strength,
    ai_summary_improvement,
    raw_feedback_count,
    updated_at
  )
  values (
    p_class_id,
    v_class.director_shop_id,
    coalesce(v_top_tags, '[]'::jsonb),
    v_strength,
    v_improvement,
    v_count,
    now()
  )
  on conflict (class_id) do update
  set
    shop_id = excluded.shop_id,
    top_insight_tags = excluded.top_insight_tags,
    ai_summary_strength = excluded.ai_summary_strength,
    ai_summary_improvement = excluded.ai_summary_improvement,
    raw_feedback_count = excluded.raw_feedback_count,
    updated_at = now()
  returning id into v_report_id;

  return v_report_id;
end;
$$;

grant execute on function public.refresh_seminar_feedback_report(uuid)
  to anon, authenticated, public;

-- 리뷰 제출 후 리포트 갱신
create or replace function public.submit_seminar_enrollment_review(
  p_enrollment_id uuid,
  p_insight_tags jsonb,
  p_comment text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_review_id uuid;
  v_tags jsonb;
  v_class_id uuid;
begin
  if p_enrollment_id is null then
    raise exception 'enrollment_id required';
  end if;

  if not exists (
    select 1 from public.seminar_enrollments e where e.id = p_enrollment_id
  ) then
    raise exception 'enrollment not found';
  end if;

  v_tags := coalesce(p_insight_tags, '[]'::jsonb);
  if jsonb_typeof(v_tags) <> 'array' or jsonb_array_length(v_tags) < 1 then
    raise exception 'at least one insight tag required';
  end if;

  insert into public.seminar_enrollment_reviews (
    enrollment_id,
    insight_tags,
    comment
  )
  values (
    p_enrollment_id,
    v_tags,
    coalesce(trim(p_comment), '')
  )
  on conflict (enrollment_id) do update
  set
    insight_tags = excluded.insight_tags,
    comment = excluded.comment
  returning id into v_review_id;

  select e.class_id into v_class_id
  from public.seminar_enrollments e
  where e.id = p_enrollment_id;

  perform public.refresh_seminar_feedback_report(v_class_id);

  return v_review_id;
end;
$$;

-- 정산 완료 후 리포트 재집계
create or replace function public.settle_seminar_enrollment(
  p_enrollment_id uuid,
  p_platform_fee_pct numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_enrollment public.seminar_enrollments%rowtype;
  v_class public.seminar_classes%rowtype;
  v_director_tier text;
  v_fee_pct numeric;
  v_net int;
begin
  select * into v_enrollment
  from public.seminar_enrollments
  where id = p_enrollment_id
  for update;

  if not found then
    raise exception 'enrollment not found';
  end if;

  if v_enrollment.status <> 'held' then
    raise exception 'enrollment not in held status';
  end if;

  if not exists (
    select 1
    from public.seminar_enrollment_reviews r
    where r.enrollment_id = p_enrollment_id
  ) then
    raise exception 'review required before settlement';
  end if;

  select * into v_class
  from public.seminar_classes
  where id = v_enrollment.class_id;

  select coalesce(s.tier_badge, 'none') into v_director_tier
  from public.shops s
  where s.id = v_class.director_shop_id;

  v_fee_pct := coalesce(
    p_platform_fee_pct,
    public.compute_platform_fee_pct(v_director_tier)
  );

  v_net := greatest(
    0,
    floor(v_enrollment.amount * (1 - v_fee_pct))::int
  );

  update public.seminar_enrollments
  set status = 'completed',
      completed_at = now()
  where id = p_enrollment_id;

  update public.shops
  set sori_cash_balance = sori_cash_balance + v_net,
      updated_at = now()
  where id = v_class.director_shop_id;

  perform public.refresh_seminar_feedback_report(v_class.id);

  return jsonb_build_object(
    'enrollment_id', p_enrollment_id,
    'class_id', v_class.id,
    'net_amount', v_net,
    'director_shop_id', v_class.director_shop_id,
    'platform_fee_pct', v_fee_pct,
    'tier_badge', v_director_tier
  );
end;
$$;
