-- SORI security snapshot: storage.buckets rows (5) + storage.objects policies (12)
-- project: tieojdbzmqcmlwyqltrk / captured at 2026-10-02 22:30:45.429761+00 (UTC) = 2026-10-03 KST
-- server: PostgreSQL 17.6 on aarch64-unknown-linux-gnu, compiled by gcc (GCC) 15.2.0, 64-bit
-- Generated read-only from catalog queries (pg_policies, pg_class.relacl, pg_proc, pg_views, storage.buckets).
-- See README.md in this folder before running anything.

begin;

-- ---- buckets (public flag, limits, mime types). Re-creates a bucket row if it was deleted. ----
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('chart-photos', 'chart-photos', true, NULL, NULL)
  on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('chart-signatures', 'chart-signatures', true, NULL, NULL)
  on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('chart_photos', 'chart_photos', true, NULL, NULL)
  on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('consent_pdfs', 'consent_pdfs', true, NULL, NULL)
  on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('shop_profiles', 'shop_profiles', true, NULL, NULL)
  on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- ---- storage.objects policies ----
-- Drop every storage policy that did NOT exist at snapshot time (e.g. policies added by later P0 migrations).
do $$
declare p record;
begin
  for p in select tablename, policyname from pg_policies where schemaname = 'storage' 
    and (tablename::text, policyname::text) not in (values
    ('objects','chart_photos_auth_delete'),
    ('objects','chart_photos_auth_insert'),
    ('objects','chart_photos_auth_update'),
    ('objects','chart_photos_public_select'),
    ('objects','consent_pdfs_auth_insert'),
    ('objects','consent_pdfs_public_select'),
    ('objects','shop_profiles_anon_insert'),
    ('objects','shop_profiles_anon_update'),
    ('objects','shop_profiles_authenticated_delete'),
    ('objects','shop_profiles_authenticated_insert'),
    ('objects','shop_profiles_authenticated_update'),
    ('objects','shop_profiles_public_select')) loop
    execute format('drop policy %I on storage.%I', p.policyname, p.tablename);
  end loop;
end $$;

drop policy if exists chart_photos_auth_delete on storage.objects;
create policy chart_photos_auth_delete on storage.objects as PERMISSIVE for DELETE to PUBLIC
  using (((bucket_id = 'chart_photos'::text) AND (auth.role() = 'authenticated'::text)));
drop policy if exists chart_photos_auth_insert on storage.objects;
create policy chart_photos_auth_insert on storage.objects as PERMISSIVE for INSERT to PUBLIC
  with check (((bucket_id = 'chart_photos'::text) AND (auth.role() = 'authenticated'::text)));
drop policy if exists chart_photos_auth_update on storage.objects;
create policy chart_photos_auth_update on storage.objects as PERMISSIVE for UPDATE to PUBLIC
  with check (((bucket_id = 'chart_photos'::text) AND (auth.role() = 'authenticated'::text)));
drop policy if exists chart_photos_public_select on storage.objects;
create policy chart_photos_public_select on storage.objects as PERMISSIVE for SELECT to PUBLIC
  using ((bucket_id = 'chart_photos'::text));
drop policy if exists consent_pdfs_auth_insert on storage.objects;
create policy consent_pdfs_auth_insert on storage.objects as PERMISSIVE for INSERT to PUBLIC
  with check (((bucket_id = 'consent_pdfs'::text) AND (auth.role() = 'authenticated'::text)));
drop policy if exists consent_pdfs_public_select on storage.objects;
create policy consent_pdfs_public_select on storage.objects as PERMISSIVE for SELECT to PUBLIC
  using ((bucket_id = 'consent_pdfs'::text));
drop policy if exists shop_profiles_anon_insert on storage.objects;
create policy shop_profiles_anon_insert on storage.objects as PERMISSIVE for INSERT to anon
  with check ((bucket_id = 'shop_profiles'::text));
drop policy if exists shop_profiles_anon_update on storage.objects;
create policy shop_profiles_anon_update on storage.objects as PERMISSIVE for UPDATE to anon
  using ((bucket_id = 'shop_profiles'::text))
  with check ((bucket_id = 'shop_profiles'::text));
drop policy if exists shop_profiles_authenticated_delete on storage.objects;
create policy shop_profiles_authenticated_delete on storage.objects as PERMISSIVE for DELETE to authenticated
  using ((bucket_id = 'shop_profiles'::text));
drop policy if exists shop_profiles_authenticated_insert on storage.objects;
create policy shop_profiles_authenticated_insert on storage.objects as PERMISSIVE for INSERT to authenticated
  with check ((bucket_id = 'shop_profiles'::text));
drop policy if exists shop_profiles_authenticated_update on storage.objects;
create policy shop_profiles_authenticated_update on storage.objects as PERMISSIVE for UPDATE to authenticated
  using ((bucket_id = 'shop_profiles'::text))
  with check ((bucket_id = 'shop_profiles'::text));
drop policy if exists shop_profiles_public_select on storage.objects;
create policy shop_profiles_public_select on storage.objects as PERMISSIVE for SELECT to PUBLIC
  using ((bucket_id = 'shop_profiles'::text));

commit;
