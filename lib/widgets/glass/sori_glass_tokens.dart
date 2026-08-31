import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';

/// GIS material tiers — L2 chips use pseudo-glass (no blur).
enum SoriGlassTier {
  l1Surface,
  l2Control,
  l3Overlay,
}

/// Semantic action variants for glass chips.
enum SoriGlassSemantic {
  neutral,
  like,
  comment,
  mentoring,
  boost,
  bookmark,
}

abstract final class SoriGlassTokens {
  static const double chipSm = 32;
  static const double chipMd = 40;
  static const double chipLg = 44;

  static const double dockGap = 12;
  static const double dockPadH = 12;
  static const double dockPadV = 8;

  static double blurSigma(SoriGlassTier tier) => switch (tier) {
        SoriGlassTier.l1Surface => 12,
        SoriGlassTier.l2Control => 0,
        SoriGlassTier.l3Overlay => 24,
      };

  static ImageFilter blurFilter(SoriGlassTier tier) {
    final sigma = blurSigma(tier);
    if (sigma <= 0) {
      return ImageFilter.blur(sigmaX: 0, sigmaY: 0);
    }
    return ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
  }

  static Color fillColor(SoriGlassTier tier, {bool pressed = false}) =>
      switch (tier) {
        SoriGlassTier.l1Surface =>
          Colors.white.withValues(alpha: pressed ? 0.84 : 0.76),
        SoriGlassTier.l2Control =>
          Colors.white.withValues(alpha: pressed ? 0.88 : 0.72),
        SoriGlassTier.l3Overlay =>
          Colors.white.withValues(alpha: pressed ? 0.90 : 0.82),
      };

  static BoxDecoration pseudoChipDecoration({
    required double radius,
    SoriGlassSemantic semantic = SoriGlassSemantic.neutral,
    bool active = false,
    bool pressed = false,
  }) {
    final top = Colors.white.withValues(alpha: pressed ? 0.92 : 0.84);
    final bottom = Colors.white.withValues(alpha: pressed ? 0.76 : 0.58);
    final tint = _semanticTint(semantic, active: active);
    List<Color> colors = [top, bottom];
    if (tint != null) {
      colors = [
        Color.lerp(top, tint, 0.38)!,
        Color.lerp(bottom, tint, 0.48)!,
      ];
    }
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 26,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration overlayDecoration({required double radius}) {
    return BoxDecoration(
      color: fillColor(SoriGlassTier.l3Overlay),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 26,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration dockTrayDecoration({required double radius}) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.78),
          Colors.white.withValues(alpha: 0.62),
        ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static Color iconColor(SoriGlassSemantic semantic, {required bool active}) {
    if (!active) return SoriTokens.textTertiary;
    return switch (semantic) {
      SoriGlassSemantic.like => SoriTokens.systemRed,
      SoriGlassSemantic.comment => SoriTokens.accentLink,
      SoriGlassSemantic.mentoring => SoriTokens.alignWarm,
      SoriGlassSemantic.boost => SoriTokens.alignEmerald,
      SoriGlassSemantic.bookmark => SoriTokens.textPrimary,
      SoriGlassSemantic.neutral => SoriTokens.textPrimary,
    };
  }

  static Color? _semanticTint(SoriGlassSemantic semantic, {required bool active}) {
    if (!active) return null;
    return switch (semantic) {
      SoriGlassSemantic.like => SoriTokens.systemRed.withValues(alpha: 0.14),
      SoriGlassSemantic.comment => SoriTokens.accentLink.withValues(alpha: 0.12),
      SoriGlassSemantic.mentoring => SoriTokens.alignWarm.withValues(alpha: 0.18),
      SoriGlassSemantic.boost => SoriTokens.alignEmerald.withValues(alpha: 0.16),
      SoriGlassSemantic.bookmark => SoriTokens.primary.withValues(alpha: 0.10),
      SoriGlassSemantic.neutral => SoriTokens.primarySoft,
    };
  }

  static Color _semanticGlow(SoriGlassSemantic semantic) => switch (semantic) {
        SoriGlassSemantic.like => SoriTokens.systemRed,
        SoriGlassSemantic.comment => SoriTokens.accentLink,
        SoriGlassSemantic.mentoring => SoriTokens.alignWarm,
        SoriGlassSemantic.boost => SoriTokens.alignEmerald,
        SoriGlassSemantic.bookmark => SoriTokens.textPrimary,
        SoriGlassSemantic.neutral => SoriTokens.textPrimary,
      };
}
