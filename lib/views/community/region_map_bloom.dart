import 'package:flutter/material.dart';

/// SORI Local Bloom — 지도 semantic 색 (DESIGN LAWS §3 · §8).
abstract final class RegionMapBloom {
  RegionMapBloom._();

  /// 커뮤니티 글 marker · Purple
  static const Color post = Color(0xFF6D4A77);

  /// 세미나 marker · Coral
  static const Color seminar = Color(0xFFD96462);

  /// 상권 · low-emphasis neutral
  static const Color market = Color(0xFF94A3B8);

  /// GPS active · Blue
  static const Color gpsActive = Color(0xFF2563EB);

  /// 선택 ring · cream
  static const Color selectRing = Color(0xFFFCF9F5);

  /// Peek/Half sheet cream
  static const Color sheetCream = Color(0xFFFCF9F5);
}
