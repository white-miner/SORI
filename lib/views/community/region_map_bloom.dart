import 'package:flutter/material.dart';

import '../../features/visit/home_visual_tokens.dart';
import '../../theme/sori_tokens.dart';

/// SORI Local Bloom — 지도 semantic 색 (DESIGN LAWS §3 · §8).
abstract final class RegionMapBloom {
  RegionMapBloom._();

  /// 커뮤니티 글 marker · 브랜드 보라 (홈 「신규 고객」과 동일, 다른 hex 금지)
  static const Color post = SoriTokens.brand;

  /// 세미나 marker · Coral
  static const Color seminar = Color(0xFFD96462);

  /// 상권 · low-emphasis neutral
  static const Color market = Color(0xFF94A3B8);

  /// GPS active · Blue
  static const Color gpsActive = Color(0xFF2563EB);

  /// 선택 ring · cream. 글·세미나 핀 전용.
  static const Color selectRing = Color(0xFFFCF9F5);

  /// Peek/Half sheet cream
  static const Color sheetCream = Color(0xFFFCF9F5);

  /// 지도 위 검색 패널·선택 카드. Desk 히어로와 같은 반투명 흰색.
  static const Color panelFill = HomeVisualTokens.heroCardFill;

  static const double mapClipRadius = HomeVisualTokens.heroCardRadius;

  static const double shopCardRadius = HomeVisualTokens.caseCardRadius;

  static const BoxShadow panelShadow = HomeVisualTokens.heroCardShadow;

  static const Color shopTitleColor = HomeVisualTokens.dateTextColor;

  static const Color shopMetaColor = HomeVisualTokens.dateIconColor;

  static const double shopTitleSize = HomeVisualTokens.caseHeaderSize;

  static const double shopMetaSize = HomeVisualTokens.caseCaptionSize;

  static const double shopAuxSize = 12;

  /// 선택된 샵 마커 링. 글 마커 [post]와 같은 브랜드 보라.
  static const Color shopSelectRing = SoriTokens.brand;

  /// 선택된 샵 마커 glow. 브랜드 보라 약 28%.
  static const Color shopSelectGlow = Color(0x478B5CF6);
}
