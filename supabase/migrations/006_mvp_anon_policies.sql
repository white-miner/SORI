-- MVP client access for anon key (tighten with auth.uid() policies before production)

-- shops
drop policy if exists "mvp_shops_select" on public.shops;
drop policy if exists "mvp_shops_insert" on public.shops;
drop policy if exists "mvp_shops_update" on public.shops;
create policy "mvp_shops_select" on public.shops for select using (true);
create policy "mvp_shops_insert" on public.shops for insert with check (true);
create policy "mvp_shops_update" on public.shops for update using (true);

-- customers
drop policy if exists "mvp_customers_select" on public.customers;
drop policy if exists "mvp_customers_insert" on public.customers;
drop policy if exists "mvp_customers_update" on public.customers;
create policy "mvp_customers_select" on public.customers for select using (true);
create policy "mvp_customers_insert" on public.customers for insert with check (true);
create policy "mvp_customers_update" on public.customers for update using (true);

-- customer_charts
drop policy if exists "mvp_charts_select" on public.customer_charts;
drop policy if exists "mvp_charts_insert" on public.customer_charts;
drop policy if exists "mvp_charts_update" on public.customer_charts;
create policy "mvp_charts_select" on public.customer_charts for select using (true);
create policy "mvp_charts_insert" on public.customer_charts for insert with check (true);
create policy "mvp_charts_update" on public.customer_charts for update using (true);

-- customer_reviews
drop policy if exists "mvp_reviews_select" on public.customer_reviews;
drop policy if exists "mvp_reviews_insert" on public.customer_reviews;
drop policy if exists "mvp_reviews_update" on public.customer_reviews;
create policy "mvp_reviews_select" on public.customer_reviews for select using (true);
create policy "mvp_reviews_insert" on public.customer_reviews for insert with check (true);
create policy "mvp_reviews_update" on public.customer_reviews for update using (true);

-- ai_replies
drop policy if exists "mvp_ai_replies_select" on public.ai_replies;
drop policy if exists "mvp_ai_replies_insert" on public.ai_replies;
drop policy if exists "mvp_ai_replies_update" on public.ai_replies;
create policy "mvp_ai_replies_select" on public.ai_replies for select using (true);
create policy "mvp_ai_replies_insert" on public.ai_replies for insert with check (true);
create policy "mvp_ai_replies_update" on public.ai_replies for update using (true);

-- profiles (read own still preferred; allow select for MVP directory)
drop policy if exists "mvp_profiles_select" on public.profiles;
create policy "mvp_profiles_select" on public.profiles for select using (true);
