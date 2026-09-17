# PRD: VIP 스페셜 후원 (Premium Overlay) — v1

> PO 승인: 2026-08-28 · 마이그레이션 `081_boost_premium_overlay.sql`

## 문제

Micro 부스터 후원(5E)은 기존 활성 `boost_placements`를 **취소 후 교체**한다. 원장이 이미 부스트한 케이스에 고액 후원을내도 “시간만 연장”처럼 느껴지고, 프리미엄 존재감이 없다.

## 해결: Premium Overlay

스페셜 후원은 **기존 부스트를 건드리지 않고** `boost_premium_overlays`에 스택된다.

| SKU | 가격 | 기간 | 효과 |
|-----|------|------|------|
| `boost_special_gold_24h` | 39E | 24h | 골드 오로라 링, 골드 스트립, 피드 score +0.12 |
| `boost_special_platinum_7d` | 149E | 7d | 플래티넘 오로라, 마이페이지 히어로 슬롯 7일, score +0.22 |

## UI 카피 (금지: 팬/Fan)

- **스페셜 후원** / **프리미엄 후원자** / **골드** / **플래티넘**
- 구매 시트: “이미 부스트 중이어도 스페셜 후원은 위에 겹쳐집니다”

## RPC

- `purchase_special_supporter_gift` — Echo 차감, overlay 생성, `fan_gifts` 기록, `special_supporter` 알림
- `list_active_premium_overlays` — 피드 어노테이션용

## 수동 배포 체크리스트

1. Supabase SQL Editor에서 `081_boost_premium_overlay.sql` 실행
2. GitHub Pages 자동 배포 (main push)
