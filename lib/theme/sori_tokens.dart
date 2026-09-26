import 'dart:ui';

import 'package:flutter/material.dart';

/// SORI — iOS-style White Minimal + System Accent (Red alerts, Camera Yellow).
abstract final class SoriTokens {
  /// App canvas — warm white (#FBF9F6). 2026-09-26 app default (was #F4F6F9).
  /// Reads white, not beige or gray. Cards, sheets, dialogs and text fields
  /// stay [surface] white on top of it.
  static const Color canvas = Color(0xFFFBF9F6);

  /// Legacy name for [canvas]. Kept so existing screens follow the new canvas.
  static const Color background = canvas;

  /// Warm muted fill for grouped rows, inset tiles and text fields that sit
  /// inside white cards/sheets (#F2F0EC). Visibly distinct from [surface]
  /// white (1.14:1) and from [canvas] (1.08:1).
  static const Color fillMuted = Color(0xFFF2F0EC);

  /// Inline link / read-more accent
  static const Color accentLink = Color(0xFF007AFF);

  static const Color surface = Color(0xFFFFFFFF);

  static const Color surfaceElevated = Color(0xFFFFFFFF);

  static const Color surfaceOverlay = Color(0xFFF0F0F0);

  /// CTA, active tab, loading — deep charcoal / pure black
  /// (레거시 호환 유지. DESIGN LAWS Purple CTA는 [brand]로 Expand.)
  static const Color primary = Color(0xFF18181B);

  static const Color primaryDark = Color(0xFF000000);

  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color primaryLight = Color(0xFF27272A);

  static const Color onPrimaryLight = Color(0xFFFFFFFF);

  /// Brand purple — LOCKED. SSOT is the Home tab 「신규 고객」 button fill.
  /// Hex `#8B5CF6`. Do not invent another purple. Do not change this value.
  /// 기존 [primary] charcoal은 일괄 치환하지 않는다. 새 surface부터 이 토큰을 쓴다.
  static const Color brand = Color(0xFF8B5CF6);

  static const Color onBrand = Color(0xFFFFFFFF);

  /// Blue — GPS / 지도 / 탐색 / 정보
  static const Color semanticBlue = Color(0xFF2563EB);

  /// Green — 완료 / 성공 / 정상
  static const Color semanticGreen = Color(0xFF15803D);

  /// Yellow — 확인 필요 / 미완료
  static const Color semanticYellow = Color(0xFFCA8A04);

  /// Coral — 세미나 marker / 시간 민감 (파괴는 [destructive])
  static const Color semanticCoral = Color(0xFFD96462);

  /// Map select ring (Local Bloom)
  static const Color mapSelectRing = Color(0xFFFCF9F5);

  /// 우리지역 샵 카드 정보 칩 — 글자색 + 아주 옅은 같은 색 배경(알약).
  /// 글자/배경 대비 WCAG AA 4.5:1 이상. [정상 영업] 파랑 · [N년째 영업] 초록 ·
  /// [업종] 핑크 · [거리] 중립.
  static const Color shopChipOpenText = Color(0xFF2563EB);
  static const Color shopChipOpenBg = Color(0xFFEEF3FE);
  static const Color shopChipYearsText = Color(0xFF157A45);
  static const Color shopChipYearsBg = Color(0xFFEAF6EF);
  static const Color shopChipIndustryText = Color(0xFFC23A62);
  static const Color shopChipIndustryBg = Color(0xFFFDEEF3);
  static const Color shopChipNeutralText = Color(0xFF5E6272);
  static const Color shopChipNeutralBg = fillMuted;

  /// 네이버 브랜드 그린 — 「네이버에서 샵 찾기」 버튼 전용.
  static const Color naverGreen = Color(0xFF03C75A);
  static const Color onNaverGreen = Color(0xFFFFFFFF);

  /// Motion budgets (ms) — DESIGN LAWS §5
  static const int motionPressMs = 90;
  static const int motionReleaseMs = 180;
  static const int motionMarkerMs = 140;

  static const Color accent = primary;

  static const Color indigo = primary;

  static const Color premium = primaryLight;

  static const Color premiumSoft = Color(0x1A18181B);

  /// iOS System Red — notification badges, warnings, delete ONLY.
  static const Color systemRed = Color(0xFFFF3B30);

  static const Color systemRedAlt = SoriTokens.systemRed;

  static const Color destructive = systemRed;

  /// Apple Camera Yellow — viewfinder alignment & preset dock ONLY.
  static const Color cameraYellow = Color(0xFFFFD60A);

  static const Color cameraYellowAlt = Color(0xFFFFCC00);

  /// Face ghost silhouette overlay (use with opacity ~10%).
  static const Color ghostImage = Color(0xFFFFFFFF);

  /// Viewfinder proximity feedback — cold / warm / locked.
  static const Color alignCold = Color(0xFF8E9AAF);
  static const Color alignWarm = Color(0xFFFF9F0A);
  /// Apple System-like emerald — decollete / face lock glow.
  static const Color alignEmerald = Color(0xFF00D289);

  /// Inactive camera preset icon
  static const Color inactiveGray = Color(0xFF71717A);

  static const Color outlinePurple = Color(0x14000000);

  static const Color outline = outlinePurple;

  static const Color border = Color(0x14000000);

  /// Form field outline — light gray (white mode).
  static const Color inputBorder = Color(0xFFE5E5EA);

  /// Idle chip / unselected control fill.
  static const Color chipIdleBg = Color(0xFFF1F1F1);

  /// Content chip — selected fill (charcoal; not brand purple).
  static const Color chipSelectedFill = Color(0xFF111111);

  /// Content chip — unselected thin border.
  static const Color chipUnselectedBorder = Color(0xFFE5E5EA);

  /// Deep charcoal — default body text on white backgrounds
  static const Color textCharcoal = Color(0xFF111111);

  static const Color textPrimary = textCharcoal;

  static const Color textSecondary = Color(0xB3111111);

  static const Color textTertiary = Color(0x73111111);

  static const Color textQuaternary = Color(0x4D111111);

  /// Tab bar — unselected label on white canvas
  static const Color tabUnselected = Color(0xFF71717A);

  /// YouTube-style selected tab capsule background
  static const Color tabCapsuleBg = Color(0xFFF1F1F1);

  static const Color success = primary;

  static const Color warningBg = Color(0xFFF5F5F5);

  static const Color warningText = Color(0xFF52525B);

  /// Glass overlays — white @ 80%
  static const Color glassFill = Color(0xCCFFFFFF);

  static const Color primaryGlass = glassFill;

  static const Color primarySoft = Color(0x1418181B);

  static const double glassBlurSigma = 10;

  static const double radiusLg = 20;
  static const double radiusXl = 24;
  static const double radiusMd = 14;

  /// Hero / content card radius (Weverse fields).
  static const double radiusHero = 20;

  /// Section header title size (T5).
  static const double typeSection = 22;

  static const double outlineWidth = 1;

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 26,
          offset: const Offset(0, 8),
        ),
      ];

  static Border get signatureBorder => Border.all(
        color: border,
        width: outlineWidth,
      );

  static BoxDecoration card({
    Color color = surface,
    double radius = radiusLg,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: signatureBorder,
      boxShadow: cardShadow,
    );
  }

  static BoxDecoration glassSurface({
    double radius = radiusMd,
    bool showBorder = true,
  }) {
    return BoxDecoration(
      color: glassFill,
      borderRadius: BorderRadius.circular(radius),
      border: showBorder
          ? Border.all(color: SoriTokens.border, width: outlineWidth)
          : null,
    );
  }

  static BoxDecoration glassEmerald({
    double radius = radiusMd,
    bool border = true,
  }) =>
      glassSurface(radius: radius, showBorder: border);

  static ImageFilter get glassBlurFilter =>
      ImageFilter.blur(sigmaX: glassBlurSigma, sigmaY: glassBlurSigma);
}
