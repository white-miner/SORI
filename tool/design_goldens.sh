#!/usr/bin/env bash
# D0-1 디자인 골든 실행기 (Linux, CI 와 같은 환경).
#
#   tool/design_goldens.sh             # 커밋된 기준선과 비교
#   tool/design_goldens.sh --update    # 기준선 갱신 (--update-goldens)
#   tool/design_goldens.sh --compare [base-ref]
#       base-ref(기본 origin/main)와 현재 작업 트리를 같은 시각에 각각 그려
#       build/design_goldens_compare/{base,head}/ 에 PNG 를 남긴다.
#       '오늘' 날짜가 보이는 화면도 같은 날 그리므로 디자인 차이만 남는다.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] || cp .env.example .env
export SORI_DESIGN_GOLDENS=1
GOLDENS=test/design_goldens/goldens

case "${1:-}" in
  --update)
    flutter test --tags golden test/design_goldens --update-goldens ;;
  --compare)
    BASE="${2:-origin/main}"
    OUT=build/design_goldens_compare
    rm -rf "$OUT" && mkdir -p "$OUT/base" "$OUT/head"
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT
    git archive "$BASE" | tar -x -C "$TMP"
    # 하네스는 현재 트리 것을 쓴다(기준 ref 에 아직 없을 수 있음).
    rm -rf "$TMP/test/design_goldens" && cp -r test/design_goldens "$TMP/test/"
    cp test/support/tolerant_golden_comparator.dart "$TMP/test/support/" 2>/dev/null || true
    cp .env "$TMP/.env"
    (cd "$TMP" && flutter pub get >/dev/null && \
      flutter test --tags golden test/design_goldens --update-goldens)
    cp "$TMP/$GOLDENS"/*.png "$OUT/base/"
    flutter test --tags golden test/design_goldens --update-goldens || true
    cp "$GOLDENS"/*.png "$OUT/head/"
    # 커밋된 기준선은 되돌린다.
    git checkout -- "$GOLDENS"
    echo "비교 이미지: $OUT/base vs $OUT/head" ;;
  *)
    flutter test --tags golden test/design_goldens ;;
esac
