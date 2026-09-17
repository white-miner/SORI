import 'package:flutter/material.dart';

import '../models/shop_climate_context.dart';
import 'environment_widget_card.dart';

/// PRD v4.4 — One-Stop widget board (ENV weather only; TREND removed).
class ConsultationWidgetBoard extends StatelessWidget {
  const ConsultationWidgetBoard({
    super.key,
    required this.climate,
    required this.onEnvironmentDetail,
  });

  final ShopClimateContext climate;
  final VoidCallback onEnvironmentDetail;

  static const _boardPadding = EdgeInsets.fromLTRB(16, 0, 16, 16);
  static const _splitBreakpoint = 768.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _boardPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _splitBreakpoint;
          return EnvironmentWidgetCard(
            climate: climate,
            onDetail: onEnvironmentDetail,
            compact: wide,
          );
        },
      ),
    );
  }
}

int computeTempoLevel({
  required int scheduledCount,
  required int inProgressCount,
}) {
  final load = scheduledCount + inProgressCount;
  if (load >= 8) return 4;
  if (load >= 5) return 3;
  if (load >= 3) return 2;
  return 1;
}
