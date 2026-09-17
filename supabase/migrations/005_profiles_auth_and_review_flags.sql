-- SORI 005: Auth profiles, shop owner link, customer user link, review Naver flags

-- profiles (= app users; 1:1 with auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role text not null default 'guest'
    check (role in ('director', 'customer', 'guest')),
  name text not null default '',
  phone text not null default '',
  active_mode text not null default 'customer'
    check (active_mode in ('director', 'customer', 'guest')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_profiles_phone on public.profiles (phone);

-- shops: owner → profiles
alter table public.shops
  add column if not exists owner_user_id uuid references public.profiles (id) on delete set null;

create index if not exists idx_shops_owner on public.shops (owner_user_id);

-- customers: optional login link + keep membership on customers (not charts)
alter table public.customers
  add column if not exists user_id uuid references public.profiles (id) on delete set null;

create index if not exists idx_customers_user on public.customers (user_id);
create index if not exists idx_customers_shop_phone on public.customers (shop_id, phone);

-- reviews: Naver registration tracking (Ikea composer CTA)
alter table public.customer_reviews
  add column if not exists naver_registered boolean not null default false,
  add column if not exists naver_registered_at timestamptz;

comment on table public.profiles is 'SORI app user profile (auth.users 1:1). Requested as users.';
comment on column public.shops.owner_user_id is 'Director who owns the shop';
comment on column public.customers.user_id is 'Optional link when customer logs in via social';
comment on column public.customer_reviews.naver_registered is 'Whether review was copied/posted to Naver';

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name, phone, role, active_mode)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', ''),
    coalesce(new.raw_user_meta_data->>'phone', ''),
    'guest',
    'customer'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;

-- Dev-friendly policies (tighten before production)
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id);
