import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';

/// 가로 인덱스 rail 공통 라벨. 최소 터치 44dp.
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

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: compact ? 56 : 72, minHeight: 44),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? SoriTokens.textCharcoal : SoriTokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? SoriTokens.textCharcoal : const Color(0xFFD6D3D1),
            width: selected ? 1.5 : 1,
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
