-- Optional P0a companion: store AI original on community_posts.
-- Safe to apply after Edge + UI ship; body remains feed SSOT.

alter table public.community_posts
  add column if not exists ai_generated_body text,
  add column if not exists ai_generated_at timestamptz,
  add column if not exists ai_model text,
  add column if not exists body_source text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'community_posts_body_source_check'
  ) then
    alter table public.community_posts
      add constraint community_posts_body_source_check
      check (
        body_source is null
        or body_source in ('manual', 'ai', 'ai_edited')
      );
  end if;
end $$;

comment on column public.community_posts.ai_generated_body is
  'Immutable AI draft before director edits; feed renders body.';
comment on column public.community_posts.body_source is
  'manual | ai | ai_edited';
