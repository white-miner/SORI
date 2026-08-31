import 'package:flutter/material.dart';

import '../../../visit_kernel/theme/visit_glass_tokens.dart';
import '../models/clinical_trend_snapshot.dart';
import 'semantic_band_theme.dart';
import 'trend_sparkline.dart';
import 'widget_glass_card.dart';

/// PRD v4.4 — CTI Trend Radar iOS widget card (~160px phone).
class TrendRadarWidgetCard extends StatelessWidget {
  const TrendRadarWidgetCard({
    super.key,
    required this.snapshot,
    required this.onDetail,
    this.compact = false,
  });

  final ClinicalTrendSnapshot snapshot;
  final VoidCallback onDetail;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final top3 = snapshot.top3;
    final lead = snapshot.briefingLead;
    final leadSurge = lead?.surgePct ?? 0;
    final ambient = leadSurge >= 30
        ? [
            const Color(0xFFFFF4E5),
            Colors.white.withValues(alpha: 0.0),
          ]
        : [
            const Color(0xFFF5F5FA),
            Colors.white.withValues(alpha: 0.0),
          ];

    return WidgetGlassCard(
      ambientColors: ambient,
      ambientShadowColor: SemanticBandTheme.sparklineColor(
        null,
        surgePct: leadSurge,
      ).withValues(alpha: 0.12),
      padding: compact
          ? const EdgeInsets.all(12)
          : const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  compact ? 'TREND' : 'TREND · CLINICAL RADAR',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VisitGlassTokens.captionCalm.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: VisitGlassTokens.sage,
                  ),
                ),
              ),
              WidgetDetailChevron(onTap: onDetail),
            ],
          ),
          SizedBox(height: compact ? 6 : 10),
          if (top3.isEmpty)
            Text(
              '오늘 뚜렷한 급등 키워드 없음',
              style: VisitGlassTokens.captionCalm.copyWith(fontSize: 13),
            )
          else ...[
            Wrap(
              spacing: compact ? 6 : 8,
              runSpacing: compact ? 6 : 8,
              children: [
                for (final item in top3)
                  _SurgePill(item: item, compact: compact),
              ],
            ),
            SizedBox(height: compact ? 8 : 12),
            if (lead != null && lead.sparkline7d.length >= 2)
              LayoutBuilder(
                builder: (context, constraints) {
                  return TrendSparkline(
                    values: lead.sparkline7d,
                    width: constraints.maxWidth,
                    height: compact ? 32 : 44,
                    surgePct: lead.surgePct,
                  );
                },
              ),
            SizedBox(height: compact ? 4 : 8),
            if (lead != null)
              Row(
                children: [
                  Text(
                    'CTI ${lead.cti}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Naver ${lead.naverScore}',
                    style: VisitGlassTokens.captionCalm.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  if (snapshot.fetchedAt != null)
                    Text(
                      _freshness(snapshot.fetchedAt!),
                      style: VisitGlassTokens.captionCalm.copyWith(
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            if (lead != null && !compact) ...[
              const SizedBox(height: 8),
              Text(
                lead.narrative,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: VisitGlassTokens.captionCalm.copyWith(
                  fontSize: 12,
                  height: 1.45,
                  color: VisitGlassTokens.careSoft,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  static String _freshness(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'now';
  }
}

class _SurgePill extends StatelessWidget {
  const _SurgePill({required this.item, this.compact = false});

  final ClinicalTrendItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bg = SemanticBandTheme.surgeChipBg(item.surgePct);
    final fg = SemanticBandTheme.surgeChipText(item.surgePct);
    final label = item.surgePct > 0
        ? '${item.keyword} +${item.surgePct}%'
        : item.keyword;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
          color: fg,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
