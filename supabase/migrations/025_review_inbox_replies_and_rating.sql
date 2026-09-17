-- 025: 원장 리뷰 인박스 — 별점 · 답글 · review_replies

alter table public.customer_reviews
  add column if not exists rating smallint
    check (rating is null or (rating >= 1 and rating <= 5)),
  add column if not exists director_reply text,
  add column if not exists director_replied_at timestamptz;

comment on column public.customer_reviews.rating is
  '고객 후기 별점 1~5 (없으면 인박스에서 기본 추정)';
comment on column public.customer_reviews.director_reply is
  '원장 최신 답글 본문(denormalized)';
comment on column public.customer_reviews.director_replied_at is
  '원장 최신 답글 시각';

create table if not exists public.review_replies (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.customer_reviews (id) on delete cascade,
  shop_id uuid not null references public.shops (id) on delete cascade,
  author_role text not null default 'director'
    check (author_role in ('director', 'customer')),
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_review_replies_review
  on public.review_replies (review_id, created_at desc);
create index if not exists idx_customer_reviews_shop_status
  on public.customer_reviews (shop_id, status, created_at desc);
create index if not exists idx_customer_reviews_rating
  on public.customer_reviews (shop_id, rating desc nulls last);

alter table public.review_replies enable row level security;

drop policy if exists "mvp_review_replies_select" on public.review_replies;
drop policy if exists "mvp_review_replies_insert" on public.review_replies;
drop policy if exists "mvp_review_replies_update" on public.review_replies;
create policy "mvp_review_replies_select"
  on public.review_replies for select using (true);
create policy "mvp_review_replies_insert"
  on public.review_replies for insert with check (true);
create policy "mvp_review_replies_update"
  on public.review_replies for update using (true);

comment on table public.review_replies is
  '원장/고객 리뷰 답글 이력 — 최신 원장 답글은 customer_reviews.director_reply 에도 미러';
