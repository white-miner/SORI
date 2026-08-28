# SORI 스폰서십(Gift Economy) 기술 검토 및 기획

**Status:** PO 승인 (v3 — 후원자/팔로워 명칭, 「팬」UI 금지)  
**Owner:** Tech Lead  
**Depends on:** `075`–`080` migrations, Boost & Fill, Supporter My Page  
**Supersedes:** v2 Fan 단일화 초안

---

## 0. 제품 철학 (PO 확정 v3)

> 커뮤니티는 상거래 플랫폼이 아니다.  
> Echo로 원장의 게시물을 밀어주는 사람은 **후원자(Supporter)** 이다.  
> **UI에 「팬(Fan)」이라는 가벼운 단어를 노출하지 않는다.**

| 계급 | 정의 | UI 라벨 |
|------|------|---------|
| **팔로워** | 샵 구독만 (`shop_followers`) | `팔로워 +N명` |
| **후원자** | Echo 부스터(또는 AI 선물) 1회 이상 | `OOO님의 후원`, Facepile |
| **탑 후원자** | 샵 단위 누적 Echo 1위 (≥50E) | Facepile 맨 앞, `탑 후원자 OOO` |
| **프리미엄 후원자** | 상위 3명 & ≥200E | 랭킹 시트 배지 |

**내부 코드/DB:** `fan_*`, `source=fan_boost` 유지 (마이그레이션 비용 최소화).  
**사용자 노출:** 전부 후원자/팔로워 톤.

---

## 1. Executive Summary

| 기능 | 상태 |
|------|------|
| 부스터 후원 (Micro 5E) | ✅ `purchase_fan_gift` (078) |
| Boost & Fill | ✅ `078` sync + Edge upgrade |
| 오로라 프로필 링 | ✅ `FanBoostAuroraAvatar` |
| Facepile (Echo DESC) | ✅ `079` avatar_url |
| 후원자 명칭 UI | ✅ `080` + Flutter v3 카피 |
| 마이페이지 Facepile 간판 | ✅ `get_shop_supporter_header` + `ShopSupporterHeaderBanner` |
| 후원자 대시보드 (3종 정렬) | ✅ `SupporterDashboardSheet` |
| 감사 위스퍼 숏컷 | ⏳ Phase 2 |

---

## 2. UX — 게시물 후원 스트립

```
┌─────────────────────────────────────────┐
│  [B/A 이미지]  ← 오로라 링 (후원 활성)    │
│  ┌───────────────────────────────────┐  │
│  │ ♥ 민지님의 후원 · 외 2명이 후원    │  │  ← 핑크 글래스
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

**CTA:** `부스터 후원 · 5E` / `이 케이스 후원하기`

**플로우:**

```
후원자 → 피드 → 부스터 후원 시트
  → purchase_fan_gift(boost_bump_4h)
  → Boost & Fill (body 부실 시)
  → 오로라 링 + Facepile + 알림
  → 원장 마이페이지 Facepile 갱신
```

---

## 3. 마이페이지 간판

```
[Facepile 👤👤👤]  ← Echo DESC, 1번 = 탑 후원자
팔로워 +102명 · 후원자 12명
탑 후원자 민지님
김원장 에스테틱
```

**RPC:** `get_shop_supporter_header`, `list_shop_supporters(sort)`

**대시보드:** 최신순 / 횟수순 / 누적 Echo순 (기본 = Echo DESC)

---

## 4. DB (변경 없음 — 명칭만 UI)

- `fan_gifts`, `boost_placements.source=fan_boost`
- `080`: 알림 `후원 알림`, fallback `후원자`
- Whisper S2: `reply_to_fan_gift_id` (예정)

---

## 5. 로드맵

| Phase | 내용 | 상태 |
|-------|------|------|
| S1 | Boost & Fill + 오로라 + Facepile | ✅ Shipped |
| S1a | 후원자 명칭 + 080 | ✅ Shipped |
| S1c | 마이페이지 Facepile + 대시보드 | ✅ Shipped |
| S2 | 감사 위스퍼 숏컷 + 내가 후원한 게시물 | ⏳ |

---

## 6. PO 배포 체크리스트

1. Supabase: `078`, `079`, `080` SQL 적용
2. Edge: `ai-case-story` 재배포
3. Web: `main` push → GitHub Pages 자동 배포
