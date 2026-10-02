# SORI 보안 스냅샷 — 2026-10-03 (P0 / S0)

운영 DB(`tieojdbzmqcmlwyqltrk`)의 **보안 관련 카탈로그 상태**를 P0 보안 작업(S1~S8) 전에 통째로 떠 둔 것입니다.
Supabase 유료 브랜치를 쓰지 않기로 했기 때문에(Q13), 문제가 생기면 이 파일들과 단계별 rollback SQL로 되돌립니다.

- 캡처 시각: **2026-10-03 07:30:45 KST** (2026-10-02 22:30:45 UTC)
- 서버: PostgreSQL 17.6 (Supabase)
- 방식: 카탈로그 SELECT만 사용 (`pg_policies`, `pg_class.relacl`, `pg_proc`, `pg_views`, `pg_trigger`, `storage.buckets`). DB에는 아무것도 쓰지 않았습니다.
- 캡처 당시 `supabase_migrations.schema_migrations` 테이블이 **없었습니다**(마이그레이션 이력 없음). 저장소의 `supabase/migrations/001…122` 파일은 수동으로 적용돼 왔습니다.
- 행 데이터(고객·차트 등)는 **포함하지 않습니다**. 데이터 백업은 Supabase 대시보드의 일일 백업을 사용합니다.

## 파일

| 파일 | 내용 |
|---|---|
| `01_rls_flags.sql` | public 테이블 96개의 RLS 사용 여부(`enable/disable` + `force`) |
| `02_policies_public.sql` | public 정책 154개. 맨 앞에 **스냅샷 이후 새로 생긴 정책을 지우는 DO 블록**이 있고, 이어서 정책마다 `drop policy if exists` + `create policy` |
| `03_storage_buckets_policies.sql` | `storage.buckets` 5개(upsert: public 여부·용량·MIME 제한) + `storage.objects` 정책 12개 |
| `04_table_grants.sql` | 테이블/뷰 100개의 권한. 관계마다 `revoke all from PUBLIC, anon, authenticated, service_role` 후 스냅샷 당시 grant 재부여 |
| `05_function_grants.sql` | A) SECURITY DEFINER 함수 153개, B) 일반 함수 16개의 EXECUTE 권한, C) 기본 권한(default privileges) 기록 |
| `06_function_defs.sql` | public 함수 169개 전체 정의(`pg_get_functiondef`, `CREATE OR REPLACE` — 기존 ACL 유지). 캡처 시점 모든 함수 소유자는 `postgres` |
| `functions_md5.tsv` | 함수별 정의 md5 — 복원 전에 무엇이 바뀌었는지 확인하는 용도 |
| `07_views.sql` | public 뷰 4개 정의 |
| `08_triggers.sql` | public 트리거 27개. 스냅샷 이후 새로 생긴 트리거 삭제 + 기존 트리거 재생성 |

## 복원 방법

> ⚠️ 운영 DB에 실행하기 전에 반드시 원장님 승인을 받고, 먼저 **해당 단계의 rollback 파일**(`supabase/security/rollback/`)로 되돌릴 수 있는지 확인하세요. 스냅샷 전체 복원은 마지막 수단입니다.

1. **무엇이 바뀌었는지 먼저 확인** (읽기 전용):
   ```sql
   select p.oid::regprocedure as fn, md5(pg_get_functiondef(p.oid)) as md5
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind in ('f','p')
    order by 1;
   ```
   결과를 `functions_md5.tsv`와 비교합니다. 정책은 `select count(*) from pg_policies where schemaname='public'`(스냅샷: 154)로 대략 확인합니다.
2. **필요한 파일만, 아래 순서로** 실행합니다. `06`을 뺀 파일은 자체 `begin; … commit;`을 갖고 있고, `06`은 `psql -1`(단일 트랜잭션)로 실행하세요:
   1. `06_function_defs.sql` — 함수 정의 (정책·트리거가 함수를 참조하므로 먼저)
   2. `07_views.sql`
   3. `08_triggers.sql`
   4. `01_rls_flags.sql`
   5. `02_policies_public.sql`
   6. `03_storage_buckets_policies.sql`
   7. `04_table_grants.sql`
   8. `05_function_grants.sql`
3. 실행 방법: Supabase SQL Editor에 파일 내용을 붙여넣거나, `psql "$DB_URL" -v ON_ERROR_STOP=1 -f <파일>`.
   복원 후 `notify pgrst, 'reload schema';`를 실행해 API 스키마 캐시를 갱신합니다.

### 주의사항

- **새 DB(빈 스키마)에 복원할 때**는 함수 본문이 아직 없는 테이블을 참조할 수 있으므로
  `PGOPTIONS="-c check_function_bodies=off"`로 실행하세요. 운영 DB 자체 복원에는 필요 없습니다.
- `02_policies_public.sql` 맨 앞의 DO 블록은 **스냅샷에 없는 public 정책을 모두 삭제**합니다(P0 마이그레이션이 추가한 정책 포함). 의도한 경우에만 실행하세요.
- `08_triggers.sql`도 스냅샷에 없는 트리거를 삭제합니다. M1의 `trg_enforce_case_share_consent`, `trg_guard_shop_protected_columns`도 여기서 지워지지만, M1은 전용 rollback 파일을 쓰는 것이 맞습니다.
- `03`의 `storage.buckets`는 DML(upsert)이고, 버킷 안의 파일(`storage.objects` 행)은 건드리지 않습니다. Supabase가 Storage 테이블 직접 수정을 막는 경우 대시보드에서 public 토글로 대신합니다.
- `05`의 C) 기본 권한 중 `supabase_admin` 소유분은 `postgres`로 복원할 수 없어 주석으로만 기록했습니다.
- 함수 ACL은 항목 순서만 다를 뿐 같은 집합으로 복원됩니다(검증 시 확인).

## 검증 기록

박스의 로컬 PostgreSQL 17 임시 클러스터(운영 스키마 구조를 재현한 하네스)에 01~08을 모두 적용해 확인했습니다.
운영 DB에는 실행하지 않았습니다.

- 함수 정의 md5 169개: 운영과 일치
- 정책 지문(`pg_policies` 166행, public+storage): 운영과 일치
- 테이블 권한(`relacl`) 지문: 일치 / 뷰 정의 지문: 일치
- 함수 EXECUTE 권한: 함수마다 같은 집합(5항목), 순서만 다름
