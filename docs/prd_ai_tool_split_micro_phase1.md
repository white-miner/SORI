# AI Tool Split & Micro — Phase 1 PRD

**Status:** Approved (PO 2026-08-28)  
**Owner:** Tech Lead  
**Scope:** Micro-priced AI copy tools + low-cost feed bump (no bundle, no subscription)

---

## 1. Goals

| Goal | Metric |
|------|--------|
| Replace high-price boost bundle UX | 89E SKUs hidden; default bump 5E |
| AI habit via free quota | 5 free generations/month/shop |
| Split AI vs exposure | Separate sheets: `AiToolSheet` / `BoostBumpSheet` |
| Legacy buyer goodwill | 10× `boost_spotlight_12h` credits for past `boost_local_1d` buyers |

## 2. Out of scope (Phase 1)

- SORI Marketing Pass subscription (Phase 1.5)
- Interior / device / whisper AI categories
- FCM educator routing
- Similar-case embedding search (free stub only in UI copy)

## 3. Product SKUs

### AI Tools (`ai_tool`)

| SKU | Price | Output |
|-----|-------|--------|
| `ai_copy_marketing` | 2E (200원) | Instagram/Naver marketing copy + hashtags |
| `ai_copy_clinical` | 3E (300원) | Director-only clinical summary |
| `ai_copy_dual` | 4E (400원) | Marketing + clinical tabs |
| `ai_regenerate` | 1E (100원) | Re-run last mode (no free quota) |

**Free quota:** 5 uses/month per shop (`ai_tool_quota`). Applies to marketing/clinical/dual, not regenerate.

### Boosters (`booster`) — repriced

| SKU | Price | Duration |
|-----|-------|----------|
| `boost_bump_4h` | 5E | 4h category feed bump |
| `boost_spotlight_12h` | 9E | 12h interleave slot |
| `boost_spotlight_24h` | 15E | 24h |
| `boost_spotlight_7d` | 59E | 7d |

Legacy `boost_local_*` → `is_active = false`.

## 4. User flows

### 4.1 AI copy (chart detail / case archive)

```
Chart → "AI 카피 쓰기" → AiToolSheet
  → pick mode (marketing / clinical / dual)
  → purchase_ai_tool RPC (free quota or Echo debit)
  → Edge ai-case-story (mode param)
  → edit tabs → copy / publish to community
```

### 4.2 Feed bump (home feed / after publish)

```
Feed card → "끌어올리기 · 500원" → BoostBumpSheet
  → purchase_point_shop_item(boost_bump_4h)
  → promo credit consumed first if spotlight SKU
```

## 5. API / DB

- Migration `075_split_micro_ai_tool_pricing.sql`
- RPCs: `get_ai_tool_quota`, `purchase_ai_tool`, `complete_ai_tool_job`, `get_shop_promo_credits`
- Tables: `ai_tool_quota`, `ai_tool_jobs`, `shop_promo_credits`
- Edge: `ai-case-story` extended with `mode` + `job_id`

## 6. Flutter deliverables

| File | Action |
|------|--------|
| `lib/widgets/ai_tool_sheet.dart` | New |
| `lib/widgets/boost_bump_sheet.dart` | New |
| `lib/services/ai_tool_service.dart` | New |
| `lib/models/ai_tool.dart` | New |
| `lib/widgets/boost_purchase_sheet.dart` | Deprecated → delegates to BoostBumpSheet |
| `chart_management_page.dart` | Use AiToolSheet |
| `case_archive_page.dart` | Use AiToolSheet |
| `unified_home_feed_page.dart` | Use BoostBumpSheet |

## 7. KPI (60 days)

- AI tool WAU ≥ 30% active directors
- Paid conversion after free quota ≥ 25%
- Bump purchase rate ≥ 15% of shared cases

## 8. CS script (legacy boost)

> 과거 1일 부스터(89E)를 구매하신 원장님께 **스포트라이트 12시간 쿠폰 10장**(9E 상당×10)을 자동 지급했습니다.  
> 앱 → 피드 → 끌어올리기에서 「쿠폰 N장」으로 확인하세요.
