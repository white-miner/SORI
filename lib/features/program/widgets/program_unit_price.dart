import 'package:flutter/material.dart';

import '../../../models/program_sales.dart';
import '../../visit/home_visual_tokens.dart';

/// 단품 1회 vs 패키지 회당. 세일 빨강 없이 크기·무게로만 이득을 보여 준다.
class ProgramUnitPriceBlock extends StatelessWidget {
  const ProgramUnitPriceBlock({
    super.key,
    required this.unitPriceKrw,
    required this.visitCount,
    this.walkInPriceKrw = 0,
    this.compact = false,
  });

  final int unitPriceKrw;
  final int visitCount;
  final int walkInPriceKrw;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final beats = ProgramPricing.unitBeatsWalkIn(unitPriceKrw, walkInPriceKrw);
    final walkIn = ProgramPricing.walkInLine(walkInPriceKrw);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (walkIn != null)
          Text(
            walkIn,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              color: HomeVisualTokens.programStrike,
              decoration: beats ? TextDecoration.lineThrough : TextDecoration.none,
            ),
          ),
        Text(
          ProgramPricing.packageUnitLine(unitPriceKrw, visitCount),
          style: TextStyle(
            fontSize: beats
                ? (compact
                    ? HomeVisualTokens.programUnitSize + 1
                    : HomeVisualTokens.programUnitWinSize)
                : HomeVisualTokens.programUnitSize,
            fontWeight: beats ? FontWeight.w700 : FontWeight.w600,
            height: 1.25,
            color: HomeVisualTokens.dateTextColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
