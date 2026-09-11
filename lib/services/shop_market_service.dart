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
    this.storeItems = const [],
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
    this.centerLatitude,
    this.centerLongitude,
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
  final List<ShopMarketStoreItem> storeItems;
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
  /// fetch에 사용한 중심 좌표 (맵용 Expand).
  final double? centerLatitude;
  final double? centerLongitude;

  factory ShopMarketInsight.unavailable({
    String reason = 'unavailable',
    double? centerLatitude,
    double? centerLongitude,
  }) {
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
      storeItems: const [],
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
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
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
      storeItems: [
        for (final raw in (stores['items'] as List? ?? const []))
          if (raw is Map)
            ShopMarketStoreItem.fromMap(Map<String, dynamic>.from(raw)),
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
      centerLatitude: (map['latitude'] as num?)?.toDouble(),
      centerLongitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  static int _asInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse('$v') ?? fallback;
  }
}

class ShopMarketStoreItem {
  const ShopMarketStoreItem({
    required this.name,
    required this.categoryLabel,
    required this.chipKey,
    required this.latitude,
    required this.longitude,
    required this.distanceM,
    required this.address,
  });

  final String name;
  final String categoryLabel;
  final String chipKey;
  final double latitude;
  final double longitude;
  final int distanceM;
  final String address;

  factory ShopMarketStoreItem.fromMap(Map<String, dynamic> map) {
    return ShopMarketStoreItem(
      name: '${map['name'] ?? ''}'.trim(),
      categoryLabel: '${map['category_label'] ?? ''}'.trim(),
      chipKey: '${map['chip_key'] ?? 'other'}'.trim(),
      latitude: (map['lat'] as num?)?.toDouble() ?? 0,
      longitude: (map['lng'] as num?)?.toDouble() ?? 0,
      distanceM: ShopMarketInsight._asInt(map['distance_m']),
      address: '${map['address'] ?? ''}'.trim(),
    );
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

  /// [fallbackAddress]: 샵에 주소/좌표가 없을 때 경영 프로필 주소 등.
  /// 서울 묵시 폴백 없이, 주소 resolve 실패 시 shop_coords_missing.
  Future<ShopMarketInsight> fetch({
    required Shop shop,
    required String category,
    String? admCd,
    String? fallbackAddress,
    int radiusM = 500,
  }) async {
    final sid = shop.id.trim();
    final fb = fallbackAddress?.trim() ?? '';
    final key =
        '$sid|${category.trim()}|${admCd?.trim() ?? ''}|$fb|$radiusM';
    if (_cache != null &&
        _cacheKey == key &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _ttl) {
      return _cache!;
    }

    var working = shop;
    final shopAddr = working.address?.trim() ?? '';
    if (shopAddr.isEmpty && fb.isNotEmpty) {
      working = working.copyWith(address: fb);
    }
    final addr = (working.address?.trim().isNotEmpty ?? false)
        ? working.address!.trim()
        : fb;

    var effectiveAdm = admCd?.trim() ?? '';
    final needCoords = working.latitude == null ||
        working.longitude == null ||
        working.latitude!.abs() < 0.01;
    final needAdm = effectiveAdm.isEmpty;

    if (addr.isNotEmpty && (needCoords || needAdm)) {
      final n = await resolveNeighborhoodFromAddress(addr);
      if (n != null) {
        if (needCoords && n.latitude.abs() > 0.01 && n.longitude.abs() > 0.01) {
          working = working.copyWith(
            latitude: n.latitude,
            longitude: n.longitude,
            address: working.address ?? addr,
          );
        }
        if (needAdm && n.isLinked) {
          effectiveAdm = n.admCd;
        }
      }
    }

    final stillNeedCoords = working.latitude == null ||
        working.longitude == null ||
        working.latitude!.abs() < 0.01;
    if (stillNeedCoords && addr.isNotEmpty) {
      // ensureShopCoordinates는 실패 시 서울 폴백 → ZONE3에는 쓰지 않음
      final local = await ShopGeocodingService.instance.resolveNeighborhood(addr);
      if (local != null &&
          local.latitude.abs() > 0.01 &&
          local.longitude.abs() > 0.01) {
        working = working.copyWith(
          latitude: local.latitude,
          longitude: local.longitude,
          address: working.address ?? addr,
        );
        if (effectiveAdm.isEmpty && local.isLinked) {
          effectiveAdm = local.admCd;
        }
      }
    }

    final lat = working.latitude;
    final lng = working.longitude;
    if (lat == null || lng == null || lat.abs() < 0.01 || lng.abs() < 0.01) {
      return ShopMarketInsight.unavailable(
        reason: addr.isEmpty ? 'address_required' : 'shop_coords_missing',
      );
    }

    final locationLabel = () {
      final a = working.address?.trim() ?? addr;
      if (a.isNotEmpty) {
        final parts = a.split(RegExp(r'\s+'));
        if (parts.length >= 2) return parts[1];
        return parts.first;
      }
      return working.name.trim().isEmpty ? '매장' : working.name.trim();
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
              'adm_cd': effectiveAdm,
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
        return ShopMarketInsight.unavailable(
          reason: 'bad_response',
          centerLatitude: lat,
          centerLongitude: lng,
        );
      }
      map.putIfAbsent('latitude', () => lat);
      map.putIfAbsent('longitude', () => lng);
      final insight = ShopMarketInsight.fromMap(map);
      _cache = insight;
      _cacheAt = DateTime.now();
      _cacheKey = key;
      return insight;
    } catch (e) {
      debugPrint('get-shop-market failed: $e');
      return ShopMarketInsight.unavailable(
        reason: e.toString(),
        centerLatitude: lat,
        centerLongitude: lng,
      );
    }
  }

  /// UI용 쉬운 말. 기술 reason은 숨기되 디버그는 로그에.
  static String friendlyReason(String? raw) {
    final r = (raw ?? '').toLowerCase();
    if (r.contains('address_required')) {
      return '샵 주소를 먼저 적어 주세요';
    }
    if (r.contains('shop_coords_missing') || r.contains('coords')) {
      return '주소를 확인하지 못했어요. 도로명·지번을 조금 더 자세히 적어 주세요';
    }
    if (r.contains('adm_cd')) {
      return '동네 연결이 필요해요. 주소로 「우리 동네 연결하기」를 눌러 주세요';
    }
    if (r.contains('missing_sbiz') || r.contains('sbiz')) {
      return '상가 공공데이터 키가 아직 연결되지 않았어요';
    }
    if (r.contains('missing_mois') || r.contains('mois')) {
      return '인구 공공데이터 키가 아직 연결되지 않았어요';
    }
    if (r.contains('timeout') || r.contains('timed out')) {
      return '응답이 늦어요. 잠시 후 다시 시도해 주세요';
    }
    if (r.contains('functionexception') || r.contains('not found')) {
      return '상권 서비스를 잠시 불러오지 못했어요';
    }
    return '잠시 후 다시 시도해 주세요';
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
