import 'package:flutter/material.dart';

import 'semantic_signal_theme.dart';

/// PRD v4.6 — Weather-style metric inset + Stocks-style surge tag.
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
        vertical: compact ? 6 : 8,
        horizontal: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: 0.22),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: compact ? 18 : 22,
            height: 3,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w600,
              color: SemanticSignalTheme.secondaryTextColor,
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 12 : 15,
              fontWeight: FontWeight.w700,
              color: SemanticSignalTheme.heroTextColor,
              fontFeatures: const [FontFeature.tabularFigures()],
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
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: band == SemanticBand.green
              ? Colors.black.withValues(alpha: 0.06)
              : SemanticSignalTheme.bandColor(band).withValues(alpha: 0.25),
        ),
        boxShadow: band == SemanticBand.green
            ? null
            : [
                BoxShadow(
                  color: SemanticSignalTheme.bandColor(band)
                      .withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
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
