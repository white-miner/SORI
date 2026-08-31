import 'package:flutter/material.dart';

import '../../visit_kernel/theme/visit_glass_tokens.dart';

/// PRD v4.0 — **키워드** + 서술형 개조식 1~2줄.
class SoriNarrativeBlock extends StatelessWidget {
  const SoriNarrativeBlock({
    super.key,
    required this.headline,
    required this.narrative,
    this.icon,
    this.compact = false,
  });

  final String headline;
  final String narrative;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: compact ? 16 : 18, color: VisitGlassTokens.careSoft),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                style: TextStyle(
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: VisitGlassTokens.care,
                ),
              ),
              if (narrative.trim().isNotEmpty) ...[
                SizedBox(height: compact ? 2 : 4),
                Text(
                  narrative,
                  style: VisitGlassTokens.captionCalm.copyWith(
                    fontSize: compact ? 12 : 13,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
