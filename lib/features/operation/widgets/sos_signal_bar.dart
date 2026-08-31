import 'package:flutter/material.dart';

import '../../../visit_kernel/theme/visit_glass_tokens.dart';
import '../models/sos_signal.dart';

/// PRD v4.0 — SOS 좌측 3px 컬러 바 (CDG).
class SosSignalBar extends StatelessWidget {
  const SosSignalBar({
    super.key,
    required this.signal,
    this.child,
  });

  final SosSignal signal;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final color = signal.grade.barColor;
    if (color == null) return child ?? const SizedBox.shrink();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
            ),
          ),
          if (child != null) Expanded(child: child!),
        ],
      ),
    );
  }
}

class SosSignalBadge extends StatelessWidget {
  const SosSignalBadge({super.key, required this.signal});

  final SosSignal signal;

  @override
  Widget build(BuildContext context) {
    if (!signal.grade.showIcon) return const SizedBox.shrink();
    return Icon(
      Icons.warning_amber_rounded,
      size: 16,
      color: signal.grade == SosGrade.s3
          ? VisitGlassTokens.alert
          : VisitGlassTokens.careSoft,
    );
  }
}

class SosSignalCard extends StatelessWidget {
  const SosSignalCard({super.key, required this.signal});

  final SosSignal signal;

  @override
  Widget build(BuildContext context) {
    if (signal.grade == SosGrade.clear) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: VisitGlassTokens.cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SosSignalBadge(signal: signal),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signal.headline,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: VisitGlassTokens.care,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  signal.narrative,
                  style: VisitGlassTokens.captionCalm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
