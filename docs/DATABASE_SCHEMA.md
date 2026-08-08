# SORI Database Schema (Supabase / Postgres)

1차 MVP UI 이후 백엔드 연동용 스키마 설계안입니다.  
요청하신 `users` / `shops` / `charts` / `reviews`를 Auth·회원권 무결성에 맞게 정규화했습니다.

## ER Overview

```
auth.users 1—1 profiles
profiles 1—0..1 shops (owner)
shops 1—* customers
profiles 0..1—* customers (login link)
shops 1—* customer_charts
customers 1—* customer_charts
customer_charts 1—0..1 customer_reviews
customer_reviews 1—0..* ai_replies
```

## Tables

### `profiles` (요청명: users)

Supabase `auth.users`와 1:1. 테이블명 `users`는 Auth와 충돌하므로 `profiles`.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | `auth.users.id` |
| role | text | `director` \| `customer` \| `guest` |
| name | text | |
| phone | text | 정규화 조회용 |
| active_mode | text | 원장/고객 토글 |
| created_at / updated_at | timestamptz | |

### `shops`

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| name, phone, naver_place_url, address | text | |
| owner_user_id | uuid? FK → profiles | 원장 |
| owner_name | text | 표시용 캐시 |

### `customers` (CRM — 로그인 전에도 존재)

회원권(잔여 횟수)의 **단일 소스**. 차트에 잔여 횟수를 두지 않습니다.

| Column | Type | Notes |
|--------|------|-------|
| id, shop_id, name, phone | | |
| membership_service_name / total_visits / used_visits | | 티켓팅 |
| gender, birth_date, address, allergy… | | 차트 autofill |
| user_id | uuid? FK → profiles | 고객 로그인 매칭 |

### `customer_charts` (요청명: charts)

| Column | Type | Notes |
|--------|------|-------|
| visit_number, care_name | | |
| concern / fear / revisit chips | jsonb | |
| visit_checked, feedback_token | | |
| customer_id, shop_id | FK | 전화는 customers 조인 |

### `customer_reviews` (요청명: reviews)

| Column | Type | Notes |
|--------|------|-------|
| puzzle_selections | jsonb | 이케아 칩 |
| original_text / edited_text | text | AI 조립 문구 |
| status | text | draft…published |
| naver_registered | boolean | 네이버 등록 여부 |
| naver_registered_at | timestamptz? | |

### `ai_replies`

비동기 AI 답글 (기존 유지).

## Migrations

1. `001_sori_core_schema.sql` — shops, customers, charts, reviews, ai_replies  
2. `002_chart_writer_fields.sql` — care_name, chips, custom_chart_no  
3. `003_customer_identity_medical.sql` — identity / medical  
4. `004_membership_ticketing.sql` — membership fields on customers  
5. `005_profiles_auth_and_review_flags.sql` — profiles, owner/user links, naver flags  

## App data layer

- `SoriStore` — UI Facade (`isLoading` / `lastError` / `bootstrap` / `lookupCustomerByPhone` / `saveChartAndConfirmVisitAsync`)
- `SoriRepository` — Memory | **Supabase (CRUD 실연동)**
- Env: `SUPABASE_URL`, `SUPABASE_ANON_KEY` (`/rest/v1` suffix auto-stripped)
- Migrations `006_mvp_anon_policies.sql` — anon MVP policies (tighten before production)

### Remote write path

1. Chart save → `customer_charts` upsert + `visit_checked=true` (token trigger)
2. Membership → `customers.membership_used_visits` +1 when first confirmed
3. Phone autofill → `customers` select by normalized phone digits
