import 'dart:ui';

import 'package:flutter/material.dart';

import 'semantic_signal_theme.dart';
import 'volume_glass_theme.dart';

/// PRD v4.7 — iOS Weather inset metric block + Stocks vibrant tag.
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: compact ? 8 : 10,
            horizontal: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.42),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: compact ? 18 : 22,
                height: 3,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 4,
                    ),
                  ],
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
        ),
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
    final band = SemanticSignalTheme.bandForSurge(surgePct);
    final vibrant = SemanticSignalTheme.bandColor(band);
    final tint = vibrant.withValues(alpha: 0.14);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.38),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: vibrant.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w800,
              color: vibrant,
              fontFeatures: const [FontFeature.tabularFigures()],
              shadows: [
                Shadow(
                  color: vibrant.withValues(alpha: 0.25),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
