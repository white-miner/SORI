import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/shop.dart';
import '../features/operation/shop_geocoding_service.dart';

/// ZONE 3 — Edge `get-shop-market` 응답 (상가 + 인구).
class ShopMarketInsight {
  const ShopMarketInsight({
    required this.ok,
    required this.locationLabel,
    required this.radiusM,
    required this.category,
    required this.statsYm,
    required this.fetchedAt,
    required this.sources,
    required this.storesOk,
    required this.totalInRadius,
    required this.sameCategoryCount,
    required this.sampleNames,
    required this.storesError,
    required this.populationOk,
    required this.admCd,
    required this.dongName,
    required this.popTotal,
    required this.popMale,
    required this.popFemale,
    required this.ages,
    required this.populationError,
    required this.storesPer1kPop,
  });

  final bool ok;
  final String locationLabel;
  final int radiusM;
  final String category;
  final String statsYm;
  final DateTime? fetchedAt;
  final List<String> sources;

  final bool storesOk;
  final int totalInRadius;
  final int sameCategoryCount;
  final List<String> sampleNames;
  final String? storesError;

  final bool populationOk;
  final String? admCd;
  final String? dongName;
  final int popTotal;
  final int popMale;
  final int popFemale;
  final List<ShopMarketAgeBucket> ages;
  final String? populationError;

  final double? storesPer1kPop;

  factory ShopMarketInsight.unavailable({String reason = 'unavailable'}) {
    return ShopMarketInsight(
      ok: false,
      locationLabel: '',
      radiusM: 500,
      category: '',
      statsYm: '',
      fetchedAt: DateTime.now().toUtc(),
      sources: const [],
      storesOk: false,
      totalInRadius: 0,
      sameCategoryCount: 0,
      sampleNames: const [],
      storesError: reason,
      populationOk: false,
      admCd: null,
      dongName: null,
      popTotal: 0,
      popMale: 0,
      popFemale: 0,
      ages: const [],
      populationError: reason,
      storesPer1kPop: null,
    );
  }

  factory ShopMarketInsight.fromMap(Map<String, dynamic> map) {
    final stores = (map['stores'] as Map?)?.cast<String, dynamic>() ?? const {};
    final pop = (map['population'] as Map?)?.cast<String, dynamic>() ?? const {};
    final agesRaw = pop['ages'];
    final ages = <ShopMarketAgeBucket>[];
    if (agesRaw is List) {
      for (final a in agesRaw) {
        if (a is Map) {
          ages.add(
            ShopMarketAgeBucket(
              label: '${a['label'] ?? ''}',
              male: _asInt(a['male']),
              female: _asInt(a['female']),
              total: _asInt(a['total']),
            ),
          );
        }
      }
    }

    final sources = <String>[];
    final src = map['sources'];
    if (src is List) {
      for (final s in src) {
        final t = '$s'.trim();
        if (t.isNotEmpty) sources.add(t);
      }
    }

    return ShopMarketInsight(
      ok: map['ok'] == true,
      locationLabel: '${map['location_label'] ?? ''}',
      radiusM: _asInt(map['radius_m'], 500),
      category: '${map['category'] ?? ''}',
      statsYm: '${map['stats_ym'] ?? ''}',
      fetchedAt: DateTime.tryParse('${map['fetched_at'] ?? ''}'),
      sources: sources,
      storesOk: stores['ok'] == true,
      totalInRadius: _asInt(stores['total_in_radius']),
      sameCategoryCount: _asInt(stores['same_category_count']),
      sampleNames: [
        for (final n in (stores['sample_names'] as List? ?? const []))
          if ('$n'.trim().isNotEmpty) '$n'.trim(),
      ],
      storesError: stores['error']?.toString(),
      populationOk: pop['ok'] == true,
      admCd: pop['adm_cd']?.toString(),
      dongName: pop['dong_name']?.toString(),
      popTotal: _asInt(pop['total']),
      popMale: _asInt(pop['male']),
      popFemale: _asInt(pop['female']),
      ages: ages,
      populationError: pop['error']?.toString(),
      storesPer1kPop: (map['stores_per_1k_pop'] as num?)?.toDouble(),
    );
  }

  static int _asInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse('$v') ?? fallback;
  }
}

class ShopMarketAgeBucket {
  const ShopMarketAgeBucket({
    required this.label,
    required this.male,
    required this.female,
    required this.total,
  });

  final String label;
  final int male;
  final int female;
  final int total;
}

/// Edge `get-shop-market` 클라이언트. API 키는 Edge secrets만.
class ShopMarketService {
  ShopMarketService._();
  static final ShopMarketService instance = ShopMarketService._();

  ShopMarketInsight? _cache;
  DateTime? _cacheAt;
  String? _cacheKey;

  static const _ttl = Duration(hours: 6);

  Future<ShopMarketInsight> fetch({
    required Shop shop,
    required String category,
    String? admCd,
    int radiusM = 500,
  }) async {
    final sid = shop.id.trim();
    final key =
        '$sid|${category.trim()}|${admCd?.trim() ?? ''}|$radiusM';
    if (_cache != null &&
        _cacheKey == key &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _ttl) {
      return _cache!;
    }

    var resolved = shop;
    if (shop.latitude == null || shop.longitude == null) {
      resolved = await ShopGeocodingService.instance.ensureShopCoordinates(shop);
    }
    final lat = resolved.latitude;
    final lng = resolved.longitude;
    if (lat == null || lng == null) {
      return ShopMarketInsight.unavailable(reason: 'shop_coords_missing');
    }

    final locationLabel = () {
      final addr = resolved.address?.trim() ?? '';
      if (addr.isNotEmpty) {
        final parts = addr.split(RegExp(r'\s+'));
        if (parts.length >= 2) return parts[1];
        return parts.first;
      }
      return resolved.name.trim().isEmpty ? '매장' : resolved.name.trim();
    }();

    try {
      final client = Supabase.instance.client;
      final res = await client.functions
          .invoke(
            'get-shop-market',
            body: {
              'shop_id': sid,
              'latitude': lat,
              'longitude': lng,
              'adm_cd': admCd?.trim() ?? '',
              'category': category.trim().isEmpty ? '에스테틱' : category.trim(),
              'radius_m': radiusM,
              'location_label': locationLabel,
            },
          )
          .timeout(const Duration(seconds: 12));

      Map<String, dynamic>? map;
      final data = res.data;
      if (data is Map<String, dynamic>) {
        map = data;
      } else if (data is Map) {
        map = Map<String, dynamic>.from(data);
      } else if (data is String) {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) map = decoded;
      }
      if (map == null) {
        return ShopMarketInsight.unavailable(reason: 'bad_response');
      }
      final insight = ShopMarketInsight.fromMap(map);
      _cache = insight;
      _cacheAt = DateTime.now();
      _cacheKey = key;
      return insight;
    } catch (e) {
      debugPrint('get-shop-market failed: $e');
      return ShopMarketInsight.unavailable(reason: e.toString());
    }
  }

  /// 주소 → 행정동 자동 연결. Edge(카카오 시크릿) 우선, 로컬 dotenv 폴백.
  Future<ShopNeighborhood?> resolveNeighborhoodFromAddress(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;

    try {
      final client = Supabase.instance.client;
      final res = await client.functions
          .invoke(
            'get-shop-market',
            body: {
              'action': 'resolve_address',
              'address': trimmed,
            },
          )
          .timeout(const Duration(seconds: 8));
      Map<String, dynamic>? map;
      final data = res.data;
      if (data is Map<String, dynamic>) {
        map = data;
      } else if (data is Map) {
        map = Map<String, dynamic>.from(data);
      }
      if (map != null && map['ok'] == true) {
        final adm = '${map['adm_cd'] ?? ''}'.trim();
        if (adm.isNotEmpty) {
          return ShopNeighborhood(
            latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
            longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
            dongName: '${map['dong_name'] ?? ''}'.trim(),
            admCd: adm,
            displayLabel: '${map['display_label'] ?? map['dong_name'] ?? adm}'
                .trim(),
          );
        }
      }
    } catch (e) {
      debugPrint('resolve_address edge failed: $e');
    }

    return ShopGeocodingService.instance.resolveNeighborhood(trimmed);
  }
}
