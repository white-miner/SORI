# 홈「관리 케이스」숨기기

**Status:** Approved · 구현  
**잠금:** Perplexity 권고 1안 (2026-09-11)

## 계약

- 라벨: **홈에서 숨기기**
- 데이터: `customer_charts.home_hidden_at` (nullable timestamptz)만 기록
- `caseShared` / linked post / 차트·사진·Visit·Payment·동의 **불변**
- 복구 UI · 보관함 · 새 빈상태 · 차트 CASCADE **비범위**
- 커뮤니티 「피드에서 내리기」와 kebab **분리**

## 입구 · 통로 · 출구

1. 입구: `ManagementCaseCard` kebab → `hideManagementCaseFromHome`
2. 통로: `home_hidden_at = now()` (멱등) · remote `updateChartHomeHiddenAt`
3. 출구: `managementCaseCharts()` 가 `homeHiddenAt == null` 만 반환
