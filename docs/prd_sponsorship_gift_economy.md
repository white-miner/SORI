# SORI 스폰서십(Gift Economy) 기술 검토 및 기획

**Status:** Draft for PO review (post Phase 1 / 075)  
**Owner:** Tech Lead  
**Depends on:** `075_split_micro_ai_tool_pricing.sql`, Split & Micro SKU

---

## 0. Executive Summary

| 구분 | 현재 상태 | 스폰서십 Phase |
|------|----------|----------------|
| B2C → 노출 부스터 | ✅ `purchase_fan_boost` (057) | Micro SKU(`boost_bump_4h` 5E)로 전환 |
| B2C → AI 카피 선물 | ❌ 없음 | `purchase_sponsored_ai_tool` 신규 |
| B2B → 스포트라이트 후원 | ❌ 없음 | `b2b_sponsor` source + 파트너 지갑 |
| 원장 Opt-out | ❌ 없음 | `shop_sponsorship_settings` 신규 |
| 알림·뱃지 | ✅ 부분 (`shop_notifications`, `FanBoostCreditStrip`) | kind 확장 |

**로드맵:** S1 B2C 노출 선물 Micro화 (~1.5주) → S2 Opt-out + AI 선물 (~3주) → S3 B2B 파트너 (~3.5주)

---

## 1. 현재 구조와 재사용 자산

### 이미 구현된 B2C Fan-Boost (057)

- `purchase_fan_boost` — 고객 Echo 차감 → `boost_placements` (`source=fan_boost`)
- `paid_by_customer_id`, `fan_display_name` on `boost_placements`
- `shop_notifications` (kind=`fan_boost`)
- `FanBoostCreditStrip`, `list_fan_boost_supporters` (058)
- `unified_home_feed_page` — `onFanBoostPurchase` for customers

### Split & Micro (075) 위에 얹기

- 동일 SKU 가격표: 스폰서도 `boost_bump_4h`(5E), `ai_copy_marketing`(2E) 등 **동일 SKU 대납**
- `ai_tool_jobs` — 현재 `shop_id` 결제만; S2에서 `payer_*` 컬럼 확장

**결론:** 새 결제 엔진 불필요. `sponsorship_gifts` 메타 레이어 + RPC 통합.

---

## 2. UX/UI — 동기 부여 설계

### 2.1 B2B (유통상/도매상)

**동기:** 원장 임상 차트·기기 리뷰 = 신뢰 UGC. 유통상이 노출을 「후원」하여 간접 홍보.

| 진입점 | CTA |
|--------|-----|
| `device_review_detail_page` (기기명 매칭) | 「이 리뷰 스폰서하기」 |
| `home_feed_card` (device_info 매칭) | 「○○ 기기 케이스 후원」 |
| B2B `sori_partner` 계정 | 「스포트라이트 12h · 900원」 |

**플로우:** 파트너 → 게시물 → 후원 확인 → `boost_placements` (`source=b2b_sponsor`) → 원장 알림 → 보라색 B2B 스트립

**카피 원칙:** 「광고 구매」❌ → 「후원」「응원」✅. 게시물 본문 수정 불가.

### 2.2 B2C (고객/팬)

**플로우 A — 노출 선물 (기존 Fan-Boost 확장)**

```
피드 카드 → [끌어올리기 선물 · 500원]
  → SponsorGiftSheet (payer=customer)
  → purchase_sponsored_gift(sku=boost_bump_4h)
  → "팬 ○○님의 응원" 스트립
```

**플로우 B — AI 카피 선물 (S2 신규)**

```
케이스 상세 → [AI 마케팅 카피 선물 · 200원]
  → purchase_sponsored_ai_tool
  → ai_tool_jobs (payer=customer, beneficiary=owner shop)
  → Edge 생성 → 원장 inbox (승인 후 발행만 가능)
```

### 2.3 알림 및 뱃지

| `shop_notifications.kind` | 예시 |
|---------------------------|------|
| `sponsor_boost` | 팬 ○○님이 끌어올리기를 선물했어요 |
| `sponsor_ai` | ○○님이 AI 카피를 선물했어요 |
| `sponsor_b2b` | △△(공식파트너)님이 스포트라이트를 후원했어요 |

**`SponsorCreditStrip`** (FanBoostCreditStrip 승격)

| type | 색상 | 카피 |
|------|------|------|
| `fan` | 핑크 | 팬 ○○님의 응원 |
| `b2b` | 보라 | △△ 공식 파트너 후원 |

---

## 3. DB 스키마 — 결제자·수혜자 분리

### 3.1 원칙

1. **수혜자** = 게시물/차트 `shop_id`
2. **결제자** = `customer` | `b2b_partner` | `shop` (자가)
3. Ledger: 결제자 지갑 차감, 수혜자 `settlement_balance` **절대 불변** (057 유지)
4. AI job: 차트 소유 shop = 수혜자; `paid_by_*` = 결제자

### 3.2 `sponsorship_gifts` (신규 통합 원장 — migration 076)

```sql
create table public.sponsorship_gifts (
  id uuid primary key default gen_random_uuid(),
  beneficiary_shop_id uuid not null references shops(id),
  target_type text not null check (target_type in ('chart', 'community_post')),
  target_id uuid not null,
  payer_type text not null check (payer_type in ('customer', 'b2b_partner', 'shop')),
  payer_customer_id uuid references customers(id),
  payer_partner_id uuid references b2b_partners(id),
  payer_shop_id uuid references shops(id),
  payer_wallet_id uuid references wallets(id),
  gift_kind text not null check (gift_kind in ('boost', 'ai_tool')),
  sku text not null,
  echo_spent int not null default 0,
  boost_placement_id uuid references boost_placements(id),
  ai_tool_job_id uuid references ai_tool_jobs(id),
  point_tx_id uuid references point_transactions(id),
  sponsor_display_name text not null default '',
  sponsor_badge text not null default '',
  status text not null default 'completed',
  created_at timestamptz default now()
);
```

### 3.3 기존 테이블 확장

**`boost_placements`**

```sql
alter table boost_placements
  add column paid_by_partner_id uuid references b2b_partners(id),
  add column sponsor_display_name text default '';
-- source: shop_ad | fan_boost | b2b_sponsor
```

**`ai_tool_jobs` (075 확장)**

```sql
alter table ai_tool_jobs
  add column payer_type text default 'shop',
  add column payer_customer_id uuid,
  add column payer_partner_id uuid;
```

**`point_transactions`**

| 필드 | 자가 | B2C 스폰서 | B2B 스폰서 |
|------|------|-----------|-----------|
| `shop_id` | 원장 | **수혜자** | 수혜자 |
| `customer_id` | null | **결제자** | null |
| `kind` | boost_spend | fan_boost_spend | b2b_sponsor_spend |
| `wallet_id` | shop wallet | **customer wallet** | partner wallet |

### 3.4 통합 RPC — `purchase_sponsored_gift`

```sql
purchase_sponsored_gift(
  p_payer_type text,   -- customer | b2b_partner | shop
  p_payer_id uuid,
  p_target_type text,
  p_target_id uuid,
  p_sku text,
  p_display_name text default ''
) returns jsonb
```

내부: settings 체크 → payer wallet debit → boost/ai 분기 → `sponsorship_gifts` insert → `shop_notifications`

기존 `purchase_fan_boost` = thin wrapper (하위 호환).

---

## 4. RLS 및 권한

| 시나리오 | 해결 |
|----------|------|
| B2C가 타인 차트 AI 트리거 | `SECURITY DEFINER` RPC + Edge service role |
| 비공개 차트 후원 | `case_shared` 또는 `published` post만 |
| 결제자가 원장 wallet 조회 | payer는 gift insert 결과만 |
| AI PII | `buildDeIdentified()` 유지 |

**RPC 게이트 (공통)**

```sql
assert target public/shared;
assert shop_sponsorship_settings allow flag;
assert b2b → verification_status = 'sori_partner';
assert payer balance >= price;
assert rate_limit: 3 gifts / payer / target / day;
assert payer not in blocked_partner_ids;
```

**AI 선물:** 생성은 payer가 트리거, **커뮤니티 발행은 원장만**.

---

## 5. 어뷰징 방지 및 Opt-out

### 5.1 `shop_sponsorship_settings` (077)

```sql
create table shop_sponsorship_settings (
  shop_id uuid primary key references shops(id),
  allow_fan_boost boolean default true,
  allow_fan_ai_gift boolean default true,
  allow_b2b_boost boolean default false,   -- Opt-in
  allow_b2b_ai_gift boolean default false,
  show_sponsor_badges boolean default true,
  max_daily_sponsor_echo int default 500,
  blocked_partner_ids uuid[] default '{}',
  updated_at timestamptz default now()
);
```

### 5.2 원장 설정 UI (`shop_settings_page`)

| 토글 | 기본값 |
|------|--------|
| 팬 끌어올리기 선물 | ON |
| 팬 AI 카피 선물 | ON |
| B2B 파트너 후원 | **OFF** |
| 스폰서 뱃지 표시 | ON |

### 5.3 어뷰징 대응

| 위협 | 대응 |
|------|------|
| B2B 무작위 후원 | B2B 기본 OFF + 기기 태그 매칭 CTA (Phase 2) |
| Echo 순환 조작 | 일일 선물 상한, faucet 캡 |
| 자가 후원 랭킹 조작 | payer=beneficiary 시 랭킹 제외 |
| AI 선물 스팸 | target당 일 1회, 거절 시 7일 cooldown |

### 5.4 거절·환불

- B2B 거절 → Echo **100% payer 환불** (권장)
- Fan 선물 → 거절 시 placement cancel; Micro 금액이라 환불 생략 가능

---

## 6. 개발 로드맵

| Phase | 범위 | 공수 |
|-------|------|------|
| **S1** | Fan-Boost → Micro SKU + `SponsorGiftSheet` + `sponsorship_gifts` + 076 | ~1.5주 |
| **S2** | `shop_sponsorship_settings` + AI gift inbox + 077 | ~3주 |
| **S3** | B2B partner wallet + device_review CTA | ~3.5주 |

### Flutter 변경

| 파일 | 작업 |
|------|------|
| `fan_boost_purchase_sheet.dart` | → `sponsor_gift_sheet.dart` |
| `FanBoostCreditStrip` | → `SponsorCreditStrip` |
| `shop_settings_page.dart` | Opt-out 섹션 |
| `ai_tool_sheet.dart` | `gift_inbox` 모드 (선물 초안 검토) |

---

## 7. PO 결정 (권장)

| # | 항목 | 권장 |
|---|------|------|
| 1 | B2B 후원 기본값 | OFF (Opt-in) |
| 2 | B2B AI/부스터 거절 시 환불 | YES |
| 3 | S1 시작 시점 | 075 배포 직후 |
| 4 | B2B Echo 충전 | S3 — S1~S2는 Admin 프로모 크레딧 파일럿 |

---

## 8. Phase 1 완료 체크리스트 (참고)

- [x] `075_split_micro_ai_tool_pricing.sql`
- [x] `AiToolSheet`, `BoostBumpSheet`
- [x] `ai-case-story` mode/job_id
- [x] `docs/prd_ai_tool_split_micro_phase1.md`
- [ ] PO: Supabase 075 적용 + Edge 재배포
- [ ] PO: GitHub Actions 웹 배포 확인
