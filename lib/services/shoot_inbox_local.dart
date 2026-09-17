import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/shoot_inbox_item.dart';

/// 촬영 미연결 큐 — SharedPreferences (샵별). 멀티기기 동기화는 추후 SQL.
abstract final class ShootInboxLocal {
  static String _key(String shopId) => 'sori_shoot_inbox_$shopId';

  static Future<List<ShootInboxItem>> load(String shopId) async {
    final sid = shopId.trim();
    if (sid.isEmpty) return const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(sid));
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((e) => ShootInboxItem.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.imageUrl.trim().isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('ShootInboxLocal.load failed: $e');
      return const [];
    }
  }

  static Future<void> save(String shopId, List<ShootInboxItem> items) async {
    final sid = shopId.trim();
    if (sid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
      await prefs.setString(_key(sid), encoded);
    } catch (e) {
      debugPrint('ShootInboxLocal.save failed: $e');
    }
  }
}
