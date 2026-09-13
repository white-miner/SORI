import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'market_strategy_models.dart';

/// 위치·반경·업종·소스 버전을 묶은 상권 캐시.
class MarketQueryCache {
  MarketQueryCache({this.ttl = const Duration(hours: 6), this.staleAfter = const Duration(hours: 2)});

  static const sourceVersion = 'v1';
  final Duration ttl;
  final Duration staleAfter;
  final Map<String, MarketSnapshot> _memory = {};

  static String key({
    required double lat,
    required double lng,
    required double radiusKm,
    required String trade,
  }) {
    final geo = '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';
    return 'market:$geo:${radiusKm.toStringAsFixed(1)}:$trade:$sourceVersion';
  }

  MarketSnapshot? memoryGet(String cacheKey) => _memory[cacheKey];

  void memoryPut(String cacheKey, MarketSnapshot snap) {
    _memory[cacheKey] = snap;
  }

  Future<MarketSnapshot?> persistGet(String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_persistName(cacheKey));
    if (raw == null || raw.isEmpty) return null;
    try {
      return MarketSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> persistPut(String cacheKey, MarketSnapshot snap) async {
    memoryPut(cacheKey, snap);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_persistName(cacheKey), jsonEncode(snap.toJson()));
    } catch (_) {}
  }

  MarketDataStatus freshnessOf(MarketSnapshot snap, {DateTime? now}) {
    final at = snap.fetchedAt;
    if (at == null) return MarketDataStatus.cached;
    final age = (now ?? DateTime.now().toUtc()).difference(at.toUtc());
    if (age > ttl) return MarketDataStatus.stale;
    if (age > staleAfter) return MarketDataStatus.stale;
    return MarketDataStatus.cached;
  }

  String _persistName(String cacheKey) => 'market_cache_$cacheKey';
}
