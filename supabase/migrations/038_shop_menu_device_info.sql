-- 샵 메뉴 정규화 + 차트 기기 정보 (nullable)
create table if not exists public.shop_menus (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  name text not null,
  description text not null default '',
  device_info text,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, name)
);

comment on table public.shop_menus is '샵 서비스 메뉴 (사용 기기 device_info 는 선택/nullable)';
comment on column public.shop_menus.device_info is '사용 기기명. 미입력 시 null 허용';

create index if not exists shop_menus_shop_id_idx on public.shop_menus (shop_id);

alter table public.shop_menus enable row level security;

drop policy if exists shop_menus_select_public on public.shop_menus;
create policy shop_menus_select_public
  on public.shop_menus for select
  using (true);

drop policy if exists shop_menus_write_owner on public.shop_menus;
create policy shop_menus_write_owner
  on public.shop_menus for all
  using (
    shop_id in (
      select id from public.shops where owner_user_id = auth.uid()
    )
  )
  with check (
    shop_id in (
      select id from public.shops where owner_user_id = auth.uid()
    )
  );

alter table public.customer_charts
  add column if not exists device_info text;

comment on column public.customer_charts.device_info is
  '선택한 서비스 메뉴의 사용 기기. 메뉴에 기기 정보가 없으면 null';

-- shops.service_menu jsonb → shop_menus 동기화
create or replace function public.sync_shop_menus_from_jsonb()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  item jsonb;
  idx int := 0;
  menu_name text;
  menu_desc text;
  menu_device text;
begin
  delete from public.shop_menus where shop_id = new.id;
  if new.service_menu is null or jsonb_typeof(new.service_menu) <> 'array' then
    return new;
  end if;
  for item in select * from jsonb_array_elements(new.service_menu)
  loop
    if jsonb_typeof(item) = 'string' then
      menu_name := trim(item #>> '{}');
      menu_desc := '';
      menu_device := null;
    else
      menu_name := trim(coalesce(item->>'name', ''));
      menu_desc := coalesce(item->>'description', '');
      menu_device := nullif(trim(coalesce(item->>'device_info', '')), '');
    end if;
    if menu_name is not null and menu_name <> '' then
      insert into public.shop_menus (
        shop_id, name, description, device_info, sort_order
      ) values (
        new.id, menu_name, menu_desc, menu_device, idx
      )
      on conflict (shop_id, name) do update set
        description = excluded.description,
        device_info = excluded.device_info,
        sort_order = excluded.sort_order,
        updated_at = now();
      idx := idx + 1;
    end if;
  end loop;
  return new;
end;
$$;

drop trigger if exists trg_sync_shop_menus on public.shops;
create trigger trg_sync_shop_menus
  after insert or update of service_menu on public.shops
  for each row execute function public.sync_shop_menus_from_jsonb();
