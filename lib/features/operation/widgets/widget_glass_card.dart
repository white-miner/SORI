import 'dart:ui';

import 'package:flutter/material.dart';

import 'semantic_signal_theme.dart';

/// PRD v4.6 — iOS 3D Material widget shell (Zone B).
class WidgetGlassCard extends StatelessWidget {
  const WidgetGlassCard({
    super.key,
    required this.child,
    this.ambientColors,
    this.ambientShadowColor,
    this.semanticBand,
    this.padding = const EdgeInsets.all(16),
    this.height,
    this.materialTier = WidgetMaterialTier.thick,
  });

  final Widget child;
  final List<Color>? ambientColors;
  final Color? ambientShadowColor;
  final SemanticBand? semanticBand;
  final EdgeInsets padding;
  final double? height;
  final WidgetMaterialTier materialTier;

  @override
  Widget build(BuildContext context) {
    final tier = materialTier;
    final band = semanticBand;
    final shadowColor = ambientShadowColor ??
        (band != null
            ? SemanticSignalTheme.shellShadow(band)
            : Colors.black.withValues(alpha: 0.10));

    final gradientColors = ambientColors ??
        (band != null
            ? SemanticSignalTheme.ambientGradient(band)
            : null);

    final tintColor = band != null
        ? SemanticSignalTheme.shellTint(band).withValues(alpha: tier.tintAlpha + 0.18)
        : Colors.white.withValues(alpha: tier.fillAlpha);

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SemanticSignalTheme.widgetRadius),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SemanticSignalTheme.widgetRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: tier.blurSigma,
            sigmaY: tier.blurSigma,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tintColor,
              borderRadius:
                  BorderRadius.circular(SemanticSignalTheme.widgetRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.72),
                width: 0.5,
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
                // Inner top highlight (iOS material edge)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.55),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(padding: padding, child: child),
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
    return Material(
      color: Colors.white.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '详情',
                style: TextStyle(
                  fontSize: 12,
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
                  : const Color(0xFFE5E5EA),
            ),
          ),
      ],
    );
  }
}
