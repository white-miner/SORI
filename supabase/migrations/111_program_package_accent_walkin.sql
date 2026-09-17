-- PRD v7.1 — 패키지 뱃지 색 · 단품 1회 앵커
-- Timer Green / 신규 Violet / 세일 Red 는 앱이 쓰지 않는다. 원장이 고른 hex 만 저장.

alter table public.program_packages
  add column if not exists accent_hex text not null default '1C1C1E';

alter table public.program_packages
  add column if not exists walk_in_price_krw int not null default 0;

alter table public.program_packages
  drop constraint if exists program_packages_walk_in_price_krw_check;

alter table public.program_packages
  add constraint program_packages_walk_in_price_krw_check
  check (walk_in_price_krw >= 0);

comment on column public.program_packages.accent_hex is
  '뱃지/이름 액센트. # 없는 6자리 hex. 34C759·8B5CF6·FF3B30 은 클라이언트가 charcoal 로 되돌린다.';
comment on column public.program_packages.walk_in_price_krw is
  '단품 1회 가격. 0 이면 뷰어에서 단품 대비 줄을 숨긴다. 패키지 정가와 별개.';

notify pgrst, 'reload schema';
