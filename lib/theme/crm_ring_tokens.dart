import 'package:flutter/material.dart';

/// CRM 프로필 링 — 색상·두께·회전 속도 SSOT.
abstract final class CrmRingTokens {
  static const double ringWidth = 2.5;
  static const double ringGap = 2.0;
  static const Duration rotationDuration = Duration(seconds: 10);

  static const int yellowDays = 45;
  static const int orangeDays = 60;
  static const int redDays = 90;
  static const int neutralGraceDays = 7;

  static const Color greenStart = Color(0xFF34C759);
  static const Color greenEnd = Color(0xFF30D158);

  static const Color yellowStart = Color(0xFFFFD60A);
  static const Color yellowEnd = Color(0xFFFFE566);

  static const Color orangeStart = Color(0xFFFF9500);
  static const Color orangeEnd = Color(0xFFFFCC00);

  static const Color redStart = Color(0xFFFF3B30);
  static const Color redEnd = Color(0xFFFF6B6B);

  static const Color neutralColor = Color(0xFFE5E5EA);
}
