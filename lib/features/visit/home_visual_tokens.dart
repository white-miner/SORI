import 'package:flutter/material.dart';

/// PRD v5.4 — Home dashboard visual constitution (CDG SSOT).
abstract final class HomeVisualTokens {
  static const canvasBg = Color(0xFFF4F6F9);
  static const heroCardFill = Color(0xF2FFFFFF);
  static const heroCardRadius = 24.0;
  static const heroCardPaddingH = 16.0;
  static const heroCardPaddingTop = 20.0;
  static const heroCardPaddingBottom = 16.0;

  static const heroCardShadow = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 30,
    offset: Offset(0, 8),
  );

  static const dateIconSize = 16.0;
  static const dateIconColor = Color(0xFF8E8E93);
  static const dateTextSize = 13.0;
  static const dateTextColor = Color(0xFF111111);
  static const dateRowMinHeight = 44.0;

  static const flipDigitHeightHome = 132.0;
  static const flipDigitWidthHome = 82.0;
  static const flipColonSizeHome = 56.0;
  static const flipHeroZoneMinHeight = 200.0;
  static const flipTileFill = Color(0xFF111111);
  static const flipTileRadius = 14.0;

  static const memoBarHeight = 44.0;
  static const memoBarRadius = 22.0;
  static const memoActiveFill = Color(0xFF34C759);
  static const memoDotSize = 8.0;
  static const memoDotInset = 14.0;
  static const memoTextSize = 12.0;

  static const toolboxCardRadius = 20.0;
  static const toolboxPaddingV = 14.0;
  static const toolboxPaddingH = 4.0;
  static const toolboxIconSize = 24.0;
  static const toolboxLabelSize = 10.0;
  static const toolboxIconColor = Color(0xFF111111);
  static const toolboxLabelColor = Color(0xFF8E8E93);

  static const careGreen = Color(0xFF34C759);
  static const walkInCardRadius = 24.0;
  static const walkInCardPaddingH = 16.0;
  static const walkInCardPaddingV = 20.0;
  static const walkInCardGap = 10.0;
  static const walkInReturningFill = Color(0xFF1C1C1E);

  static const careStartHeight = 56.0;
  static const careStartRadius = 18.0;
  static const careStartTextSize = 16.0;
  static const careStartShadow = BoxShadow(
    color: Color(0x1F34C759),
    blurRadius: 16,
    offset: Offset(0, 6),
  );

  static const presetTimeChipW = 64.0;
  static const presetTimeChipH = 36.0;
  static const presetTimeChipRadius = 18.0;
  static const presetTimeTextSize = 13.0;
  static const presetLabelFill = Color(0xFFF4F6F9);
  static const presetLabelRadius = 14.0;
  static const presetLabelTextSize = 13.0;
  static const presetRowGap = 8.0;
  static const presetCardPadding = 16.0;

  static const stackedFrontW = 96.0;
  static const stackedFrontH = 44.0;
  static const stackedBackW = 72.0;
  static const stackedBackH = 34.0;
  static const stackedOffsetH = 16.0;
  static const stackedOffsetV = 20.0;
  static const stackedAddCircle = 32.0;
}
