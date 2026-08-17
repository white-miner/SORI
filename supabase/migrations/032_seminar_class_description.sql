-- 032: 세미나 클래스 상세 설명 컬럼
alter table public.seminar_classes
  add column if not exists description text not null default '';

comment on column public.seminar_classes.description is
  '강사가 작성한 세미나 랜딩 상세 설명';
