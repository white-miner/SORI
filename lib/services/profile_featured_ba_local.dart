import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/visit/profile_showcase.dart';

/// Phase 5 — 샵별 대표 B/A id 목록 (기기 로컬 · 서버 동기화 없음).
abstract final class ProfileFeaturedBaLocal {
  ProfileFeaturedBaLocal._();

  static String _key(String shopId) => 'sori_profile_featured_ba_$shopId';

  static Future<List<String>> load(String shopId) async {
    final sid = shopId.trim();
    if (sid.isEmpty) return const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(sid));
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return ProfileShowcase.normalizeFeaturedIds(
        decoded.map((e) => '$e'),
      );
    } catch (e) {
      debugPrint('ProfileFeaturedBaLocal.load failed: $e');
      return const [];
    }
  }

  static Future<void> save(String shopId, List<String> ids) async {
    final sid = shopId.trim();
    if (sid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final normalized = ProfileShowcase.normalizeFeaturedIds(ids);
      await prefs.setString(_key(sid), jsonEncode(normalized));
    } catch (e) {
      debugPrint('ProfileFeaturedBaLocal.save failed: $e');
    }
  }
}
