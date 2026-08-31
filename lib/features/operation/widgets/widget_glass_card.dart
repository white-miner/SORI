import 'dart:ui';

import 'package:flutter/material.dart';

import 'semantic_signal_theme.dart';
import 'volume_glass_theme.dart';

/// PRD v4.7 — iOS Thick Material glass widget shell (real blur + ambient).
class WidgetGlassCard extends StatelessWidget {
  const WidgetGlassCard({
    super.key,
    required this.child,
    this.ambientColors,
    this.ambientShadowColor,
    this.semanticBand,
    this.padding,
    this.height,
    this.materialTier = WidgetMaterialTier.thick,
    this.compact = false,
  });

  final Widget child;
  final List<Color>? ambientColors;
  final Color? ambientShadowColor;
  final SemanticBand? semanticBand;
  final EdgeInsets? padding;
  final double? height;
  final WidgetMaterialTier materialTier;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tier = materialTier;
    final band = semanticBand;
    final resolvedPadding = padding ??
        (compact ? VolumeGlassTheme.compactPadding : VolumeGlassTheme.cardPadding);

    final shadowTint = ambientShadowColor ??
        (band != null ? SemanticSignalTheme.shellShadow(band) : null);

    final gradientColors = ambientColors ??
        (band != null ? SemanticSignalTheme.ambientGradient(band) : null);

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius),
        boxShadow: VolumeGlassTheme.volumeShadow(
          tint: shadowTint ?? Colors.black,
          alpha: 0.04,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: tier.blurSigma,
            sigmaY: tier.blurSigma,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: tier.fillAlpha),
              borderRadius:
                  BorderRadius.circular(VolumeGlassTheme.cardRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 1,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                if (gradientColors != null && gradientColors.length >= 2)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradientColors
                              .map((c) => c.withValues(alpha: tier.ambientAlpha))
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.22),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.35],
                      ),
                    ),
                  ),
                ),
                Padding(padding: resolvedPadding, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chevron-only deep sheet trigger (PO v4.4 — no whole-card tap).
class WidgetDetailChevron extends StatelessWidget {
  const WidgetDetailChevron({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(20),
          elevation: 0,
          shadowColor: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '详情',
                    style: VolumeGlassTheme.labelTextStyle(compact: true).copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tempo micro-bar in widget header (PO v4.4).
class WidgetTempoMicroBar extends StatelessWidget {
  const WidgetTempoMicroBar({super.key, required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            width: 14,
            height: 4,
            margin: EdgeInsets.only(left: i == 0 ? 0 : 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: i < level
                  ? const Color(0xFF18181B)
                      .withValues(alpha: 0.18 + (i + 1) * 0.12)
                  : Colors.white.withValues(alpha: 0.35),
            ),
          ),
      ],
    );
  }
}
