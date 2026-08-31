import 'package:flutter/material.dart';

import '../models/clinical_trend_snapshot.dart';
import '../models/shop_climate_context.dart';
import 'environment_widget_card.dart';
import 'trend_radar_widget_card.dart';

/// PRD v4.4 — One-Stop widget board (scroll with content, no pin).
class ConsultationWidgetBoard extends StatelessWidget {
  const ConsultationWidgetBoard({
    super.key,
    required this.climate,
    required this.trends,
    required this.tempoLevel,
    required this.onEnvironmentDetail,
    required this.onTrendDetail,
  });

  final ShopClimateContext climate;
  final ClinicalTrendSnapshot trends;
  final int tempoLevel;
  final VoidCallback onEnvironmentDetail;
  final VoidCallback onTrendDetail;

  static const _boardPadding = EdgeInsets.fromLTRB(16, 0, 16, 16);
  static const _splitBreakpoint = 768.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _boardPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _splitBreakpoint;
          if (wide) {
            return SizedBox(
              height: 220,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: EnvironmentWidgetCard(
                      climate: climate,
                      tempoLevel: tempoLevel,
                      onDetail: onEnvironmentDetail,
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TrendRadarWidgetCard(
                      snapshot: trends,
                      onDetail: onTrendDetail,
                      compact: true,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EnvironmentWidgetCard(
                climate: climate,
                tempoLevel: tempoLevel,
                onDetail: onEnvironmentDetail,
              ),
              const SizedBox(height: 16),
              TrendRadarWidgetCard(
                snapshot: trends,
                onDetail: onTrendDetail,
              ),
            ],
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
