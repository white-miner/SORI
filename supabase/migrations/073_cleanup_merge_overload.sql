-- 073: PGRST203 — merge_shop_customers 오버로드 제거 (uuid 단일 시그니처 SSOT)
-- PostgREST는 JSON 문자열을 uuid로 자동 캐스팅하므로 text 오버로드 불필요.

drop function if exists public.merge_shop_customers(text, text[], jsonb);

-- uuid 버전만 유지 (072 본문과 동일 — 재적용으로 스키마 캐시 갱신)
-- 이미 존재하면 CREATE OR REPLACE 없이 DROP만으로 충분하나,
-- GRANT 재확인을 위해 주석으로 SSOT 명시.

comment on function public.merge_shop_customers(uuid, uuid[], jsonb) is
  '원장 소유 고객 중복 병합 SSOT. PostgREST: p_primary_id/p_source_ids는 JSON string→uuid 자동 캐스팅.';

grant execute on function public.merge_shop_customers(uuid, uuid[], jsonb)
  to authenticated, anon, service_role;

-- PostgREST schema cache: Supabase Dashboard에서 NOTIFY pgrst, 'reload schema' 실행 또는
-- API Settings → Reload schema (DDL 적용 후 자동 갱신되는 경우도 있음).
