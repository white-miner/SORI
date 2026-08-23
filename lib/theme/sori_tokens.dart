import 'package:flutter/material.dart';

/// SORI design tokens — Weverse Content-First dark (Phase 9).
/// Neutrals carry the UI; mint accent is allowlisted (CTA / link / toggle / badge).
abstract final class SoriTokens {
  /// Pure black canvas
  static const Color background = Color(0xFF000000);

  /// Feed cards / list containers
  static const Color surface = Color(0xFF1A1A1A);

  /// Sheets, raised panels
  static const Color surfaceElevated = Color(0xFF222222);

  /// Press / inactive chip fill
  static const Color surfaceOverlay = Color(0xFF2A2A2A);

  /// Cool mint accent — Fan-Boost CTA, 더보기, toggle ON, active badge only
  static const Color primary = Color(0xFF3EE0C5);

  /// Mint wash (~15%)
  static const Color primarySoft = Color(0x263EE0C5);

  /// Alias for accent allowlist call sites
  static const Color accent = primary;

  /// Legacy name → mint (no purple brand UI)
  static const Color indigo = primary;

  /// Hairline only when explicitly needed (default cards: none)
  static const Color outlinePurple = Color(0x14FFFFFF);

  /// 100% white — nicknames, section titles
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// ~70% — body / captions
  static const Color textSecondary = Color(0xB3FFFFFF);

  /// ~45% — shop · time · meta · inactive nav
  static const Color textTertiary = Color(0x73FFFFFF);

  /// ~30% — placeholders
  static const Color textQuaternary = Color(0x4DFFFFFF);

  static const Color border = Color(0x14FFFFFF);
  static const Color success = Color(0xFF03C75A);
  static const Color warningBg = Color(0xFF2A2118);
  static const Color warningText = Color(0xFFFBBF24);

  static const double radiusLg = 18;
  static const double radiusXl = 24;
  static const double radiusMd = 14;
  static const double outlineWidth = 1;

  /// Depth via luminance only — no heavy shadows.
  static List<BoxShadow> get cardShadow => const [];

  /// Transparent / unused — prefer no border on cards.
  static Border get signatureBorder => Border.all(
        color: Colors.transparent,
        width: 0,
      );

  static BoxDecoration card({
    Color color = surface,
    double radius = radiusLg,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
    );
  }
}
