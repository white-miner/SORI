import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/shop.dart';
import 'clinical_assistant_store.dart';
import 'clinical_trend_engine.dart';
import 'models/clinical_trend_snapshot.dart';

/// PRD v4.3 — Edge get-clinical-trends, 2h client cache.
class ShopClinicalTrendService {
  ShopClinicalTrendService._();
  static final ShopClinicalTrendService instance = ShopClinicalTrendService._();

  ClinicalTrendSnapshot? _cache;
  DateTime? _cacheAt;
  String? _cacheShopId;

  static const _cacheTtl = Duration(hours: 2);

  Future<ClinicalTrendSnapshot> fetchForShop(Shop shop) async {
    final sid = shop.id.trim();
    if (_cache != null &&
        _cacheShopId == sid &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _cacheTtl) {
      ClinicalAssistantStore.instance.setTrends(_cache!);
      return _cache!;
    }

    ClinicalTrendSnapshot? snapshot;
    try {
      final client = Supabase.instance.client;
      final res = await client.functions
          .invoke(
            'get-clinical-trends',
            body: {'shop_id': sid},
          )
          .timeout(const Duration(seconds: 8));
      snapshot = _parseResponse(res.data);
    } catch (e) {
      debugPrint('get-clinical-trends edge failed: $e');
    }

    snapshot ??= ClinicalTrendEngine.buildFallbackSnapshot();

    _cache = snapshot;
    _cacheAt = DateTime.now();
    _cacheShopId = sid;
    ClinicalAssistantStore.instance.setTrends(snapshot);
    return snapshot;
  }

  ClinicalTrendSnapshot? _parseResponse(dynamic data) {
    try {
      Map<String, dynamic>? map;
      if (data is Map<String, dynamic>) {
        map = data;
      } else if (data is String) {
        map = jsonDecode(data) as Map<String, dynamic>?;
      }
      if (map == null) return null;
      return ClinicalTrendSnapshot.fromMap(map);
    } catch (_) {
      return null;
    }
  }
}
