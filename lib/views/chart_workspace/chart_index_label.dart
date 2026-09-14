import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';

/// 가로 인덱스 rail 공통 라벨. 파일 탭 문법 — Material chip/pill 금지.
/// 선택: SORI purple 채움, 위쪽만 라운드, 하단 테두리 없음(아래 콘텐츠와
/// 시각적으로 연결). 비선택: 종이 표면처럼 조용히 존재 — 채움 없음, 선택
/// 탭보다 낮게 앉아 있다. 시각적 탭 높이는 38~44dp지만, [ChartIndexRail]의
/// 레인(56dp) 전체가 탭 영역이라 실제 터치 타깃은 항상 44dp 이상이다.
class ChartIndexLabel extends StatelessWidget {
  const ChartIndexLabel({
    super.key,
    required this.text,
    required this.selected,
    this.compact = false,
  });

  final String text;
  final bool selected;
  final bool compact;

  static const _quiet = Color(0xFFDCD8D1);
  static const _tabRadius = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(8),
  );

  /// rail 공통 레인 높이. [ChartIndexRail]의 SizedBox 높이와 짝을 이룬다.
  static const laneHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    // 모든 탭은 같은 바닥선(레인 하단)에서 시작해, 선택된 탭만 더 높이
    // 떠오른다 — 파일 탭이 서류철 위로 튀어나온 느낌.
    final tabHeight = selected ? 44.0 : 38.0;
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        height: tabHeight,
        constraints: BoxConstraints(minWidth: compact ? 52 : 68),
        padding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: selected ? 10 : 8,
        ),
        decoration: BoxDecoration(
          color: selected ? SoriTokens.brand : Colors.transparent,
          borderRadius: _tabRadius,
          border: Border(
            top: BorderSide(color: selected ? SoriTokens.brand : _quiet),
            left: BorderSide(color: selected ? SoriTokens.brand : _quiet),
            right: BorderSide(color: selected ? SoriTokens.brand : _quiet),
            // 선택 탭은 바닥 선이 없어 아래 기록지 면과 하나로 이어진다.
            bottom: selected
                ? BorderSide.none
                : const BorderSide(color: _quiet),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : SoriTokens.textCharcoal,
          ),
        ),
      ),
    );
  }
}
