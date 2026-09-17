import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../views/biz_dashboard/biz_math.dart';

/// 경영 온보딩 프로필 — 기기 로컬 (Phase 1). 추후 Supabase Expand.
abstract final class BizProfileStore {
  static String _key(String shopId) => 'biz_profile_v1_${shopId.trim()}';

  static Future<ShopBizProfile> load(String shopId) async {
    if (shopId.trim().isEmpty) return const ShopBizProfile();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(shopId));
    if (raw == null || raw.isEmpty) return const ShopBizProfile();
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return ShopBizProfile.fromJson(map);
      }
      if (map is Map) {
        return ShopBizProfile.fromJson(Map<String, dynamic>.from(map));
      }
    } catch (_) {}
    return const ShopBizProfile();
  }

  static Future<void> save(String shopId, ShopBizProfile profile) async {
    if (shopId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(shopId), jsonEncode(profile.toJson()));
  }
}
