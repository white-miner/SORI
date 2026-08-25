import 'package:flutter/material.dart';

/// SORI design tokens — Weverse-style 4축.
/// Black / Charcoal / White / Emerald(Accent).
/// 보라는 메인 금지 — [premium]은 Echo·VIP 등 명명된 예외만.
abstract final class SoriTokens {
  /// Pure black canvas
  static const Color background = Color(0xFF000000);

  /// Feed cards / list containers
  static const Color surface = Color(0xFF1A1A1A);

  /// Sheets, raised panels
  static const Color surfaceElevated = Color(0xFF222222);

  /// Press / inactive chip fill
  static const Color surfaceOverlay = Color(0xFF2A2A2A);

  /// Dark-mode primary (Luminous Emerald) — CTA / link / toggle / active badge
  static const Color primary = Color(0xFF34D399);

  /// Alias — PO 스펙 `primaryDark`
  static const Color primaryDark = primary;

  /// Emerald wash (~15%)
  static const Color primarySoft = Color(0x2634D399);

  /// Filled CTA label on [primary] (WCAG: dark on luminous emerald)
  static const Color onPrimary = Color(0xFF0B1220);

  /// Light-mode primary (Deep Emerald) — 향후 라이트 테마용
  static const Color primaryLight = Color(0xFF047857);

  /// Filled CTA label on [primaryLight]
  static const Color onPrimaryLight = Color(0xFFFFFFFF);

  /// Alias for accent allowlist call sites
  static const Color accent = primary;

  /// Legacy alias → emerald (do not reintroduce purple here)
  static const Color indigo = primary;

  /// Echo / VIP / Master-tier glow only — never main UI chrome
  static const Color premium = Color(0xFFA78BFA);

  /// Premium wash (~20%)
  static const Color premiumSoft = Color(0x33A78BFA);

  /// Hairline only when explicitly needed (default cards: none)
  /// Legacy name kept for call-site stability (not a purple color).
  static const Color outlinePurple = Color(0x14FFFFFF);

  /// Preferred hairline alias
  static const Color outline = outlinePurple;

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
