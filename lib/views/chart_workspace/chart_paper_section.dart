import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';

/// 한 장 기록지 공통 섹션 레이아웃. 카드/그림자 금지.
class ChartPaperSection extends StatelessWidget {
  const ChartPaperSection({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 28, thickness: 1, color: Color(0xFFE7E5E4)),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: SoriTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

InputDecoration chartFieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    isDense: true,
    filled: false,
    border: InputBorder.none,
    contentPadding: EdgeInsets.zero,
    hintStyle: TextStyle(
      color: SoriTokens.textSecondary.withValues(alpha: 0.55),
      fontWeight: FontWeight.w500,
    ),
  );
}

const chartBodyTextStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w600,
  height: 1.45,
  color: SoriTokens.textCharcoal,
);
