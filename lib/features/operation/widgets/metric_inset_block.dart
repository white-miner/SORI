import 'package:flutter/material.dart';

import 'semantic_signal_theme.dart';
import 'volume_glass_theme.dart';

/// PRD v4.7 — Weather-style metric inset + Stocks-style surge tag.
class MetricInsetBlock extends StatelessWidget {
  const MetricInsetBlock({
    super.key,
    required this.label,
    required this.value,
    required this.band,
    this.compact = false,
  });

  final String label;
  final String value;
  final SemanticBand band;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = SemanticSignalTheme.bandColor(band);

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 8 : 10,
        horizontal: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: VolumeGlassTheme.cardFillColor(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        boxShadow: VolumeGlassTheme.volumeShadow(
          tint: accent,
          alpha: 0.04,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: compact ? 18 : 22,
            height: 3,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            label,
            style: VolumeGlassTheme.labelTextStyle(compact: true),
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            value,
            style: VolumeGlassTheme.kpiTextStyle(compact: true).copyWith(
              fontSize: compact ? 15 : 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class SemanticTagChip extends StatelessWidget {
  const SemanticTagChip({
    super.key,
    required this.label,
    required this.surgePct,
    this.compact = false,
  });

  final String label;
  final int surgePct;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bg = SemanticSignalTheme.surgeChipBg(surgePct);
    final fg = SemanticSignalTheme.surgeChipText(surgePct);
    final band = SemanticSignalTheme.bandForSurge(surgePct);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: band == SemanticBand.green
            ? VolumeGlassTheme.volumeShadow(alpha: 0.04)
            : VolumeGlassTheme.volumeShadow(
                tint: SemanticSignalTheme.bandColor(band),
                alpha: 0.06,
              ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 12 : 13,
          fontWeight: FontWeight.w700,
          color: fg,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
