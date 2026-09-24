import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/shop.dart';
import '../features/operation/shop_geocoding_service.dart';
import '../utils/area_search_center.dart';
import 'our_area_shop_snapshot.dart';

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
    this.storesUpstream,
    this.storesComplete = false,
    this.storesSource = '',
    this.storesRetrievedAt = '',
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
  /// Edge `stores.upstream`. 없으면 구버전 응답.
  final String? storesUpstream;
  /// False for legacy, partial, failed, and snapshot responses.
  final bool storesComplete;
  /// Edge `stores.source`. 없으면 빈 문자열.
  final String storesSource;
  /// Edge `stores.retrieved_at` 원문. 파싱하지 못한 값도 그대로 둔다.
  final String storesRetrievedAt;

  static const fieldUnavailable = '현재 제공되지 않음';

  /// 화면용 출처. 비어 있으면 [fieldUnavailable].
  String get sourceText {
    final raw = storesSource.trim();
    return raw.isEmpty ? fieldUnavailable : raw;
  }

  /// 화면용 조회 시점. [statsYm]으로 대체하지 않는다.
  String get queryTimeText => formatQueryTime(storesRetrievedAt);

  static final RegExp _queryTimePattern = RegExp(
    r'^(\d{4})-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])'
    r'(?:[T ]([01]\d|2[0-3]):([0-5]\d)(?::([0-5]\d)(?:\.\d+)?)?'
    r'(Z|[+-](?:[01]\d|2[0-3]):?[0-5]\d)?)?$',
  );

  static String formatQueryTime(String raw) {
    final trimmed = raw.trim();
    final match = _queryTimePattern.firstMatch(trimmed);
    if (match == null) return fieldUnavailable;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4) ?? '0');
    final minute = int.parse(match.group(5) ?? '0');
    final second = int.parse(match.group(6) ?? '0');
    final wall = DateTime.utc(year, month, day, hour, minute, second);
    if (wall.year != year ||
        wall.month != month ||
        wall.day != day ||
        wall.hour != hour ||
        wall.minute != minute ||
        wall.second != second) {
      return fieldUnavailable;
    }
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return fieldUnavailable;
    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year.toString().padLeft(4, '0')}-'
        '${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

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
      storesSource: '',
      storesRetrievedAt: '',
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
      storesUpstream: stores['upstream']?.toString(),
      storesComplete: stores['complete'] == true,
      storesSource: _text(stores['source']),
      storesRetrievedAt: _text(stores['retrieved_at']),
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

  /// Edge 0건일 때 지역 스냅샷을 목록/마커에 붙인다. 기존 필드는 유지.
  ShopMarketInsight withFallbackStores(List<ShopMarketStoreItem> items) {
    if (items.isEmpty) return this;
    final names = [
      for (final s in items)
        if (s.name.trim().isNotEmpty) s.name.trim(),
    ].take(5).toList();
    final sources = [
      ...this.sources,
      if (!this.sources.contains(OurAreaShopSnapshot.sourceLabel))
        OurAreaShopSnapshot.sourceLabel,
    ];
    return ShopMarketInsight(
      ok: true,
      locationLabel: locationLabel,
      radiusM: radiusM,
      category: category,
      statsYm: statsYm,
      fetchedAt: fetchedAt,
      sources: sources,
      storesOk: true,
      totalInRadius: items.length,
      sameCategoryCount: items.length,
      sampleNames: names,
      storeItems: items,
      storesError: null,
      storesSource: storesSource,
      storesRetrievedAt: storesRetrievedAt,
      populationOk: populationOk,
      admCd: admCd,
      dongName: dongName,
      popTotal: popTotal,
      popMale: popMale,
      popFemale: popFemale,
      ages: ages,
      populationError: populationError,
      storesPer1kPop: storesPer1kPop,
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
    );
  }

  static int _asInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse('$v') ?? fallback;
  }

  static String _text(dynamic v) {
    if (v == null) return '';
    return '$v'.trim();
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
    this.bizesId = '',
    this.indsLclsCd = '',
    this.indsLclsNm = '',
    this.indsMclsCd = '',
    this.indsMclsNm = '',
    this.indsSclsCd = '',
    this.indsSclsNm = '',
    this.lotAddress = '',
    this.sourceAddr = '',
    this.ctprvnCd = '',
    this.ctprvnNm = '',
    this.signguCd = '',
    this.signguNm = '',
    this.adongCd = '',
    this.adongNm = '',
  });

  final String name;
  final String categoryLabel;
  final String chipKey;
  final double latitude;
  final double longitude;
  final int distanceM;
  final String address;
  final String bizesId;
  final String indsLclsCd;
  final String indsLclsNm;
  final String indsMclsCd;
  final String indsMclsNm;
  final String indsSclsCd;
  final String indsSclsNm;
  final String lotAddress;
  /// 상가 원본 `addr`. 화면 [address]에는 넣지 않고 검색 fallback에만 쓴다.
  final String sourceAddr;
  final String ctprvnCd;
  final String ctprvnNm;
  final String signguCd;
  final String signguNm;
  final String adongCd;
  final String adongNm;

  /// 소분류·중분류·대분류 이름. 코드는 넣지 않는다.
  String get industryDisplay {
    final names = <String>[];
    void add(String raw) {
      final text = raw.trim();
      if (text.isEmpty || names.contains(text)) return;
      names.add(text);
    }

    add(indsSclsNm);
    if (indsSclsNm.trim().isEmpty) add(categoryLabel);
    add(indsMclsNm);
    add(indsLclsNm);
    return names.join(' · ');
  }

  /// 네이버·내부 검색어. 도로명 → 지번 → 원본 addr. 셋 다 없으면 빈 문자열.
  String get searchPlace {
    final road = address.trim();
    if (road.isNotEmpty) return road;
    final lot = lotAddress.trim();
    if (lot.isNotEmpty) return lot;
    return sourceAddr.trim();
  }

  factory ShopMarketStoreItem.fromMap(Map<String, dynamic> map) {
    final point = AreaSearchCenter.pointFromMap(map);
    return ShopMarketStoreItem(
      name: ShopMarketInsight._text(map['name']),
      categoryLabel: ShopMarketInsight._text(map['category_label']),
      chipKey: ShopMarketInsight._text(map['chip_key']).isEmpty
          ? 'other'
          : ShopMarketInsight._text(map['chip_key']),
      latitude: point?.lat ?? 0,
      longitude: point?.lng ?? 0,
      distanceM: ShopMarketInsight._asInt(map['distance_m']),
      address: ShopMarketInsight._text(map['address']),
      bizesId: ShopMarketInsight._text(map['bizes_id']),
      indsLclsCd: ShopMarketInsight._text(map['inds_lcls_cd']),
      indsLclsNm: ShopMarketInsight._text(map['inds_lcls_nm']),
      indsMclsCd: ShopMarketInsight._text(map['inds_mcls_cd']),
      indsMclsNm: ShopMarketInsight._text(map['inds_mcls_nm']),
      indsSclsCd: ShopMarketInsight._text(map['inds_scls_cd']),
      indsSclsNm: ShopMarketInsight._text(map['inds_scls_nm']),
      lotAddress: ShopMarketInsight._text(map['lot_address']),
      sourceAddr: ShopMarketInsight._text(map['addr']),
      ctprvnCd: ShopMarketInsight._text(map['ctprvn_cd']),
      ctprvnNm: ShopMarketInsight._text(map['ctprvn_nm']),
      signguCd: ShopMarketInsight._text(map['signgu_cd']),
      signguNm: ShopMarketInsight._text(map['signgu_nm']),
      adongCd: ShopMarketInsight._text(map['adong_cd']),
      adongNm: ShopMarketInsight._text(map['adong_nm']),
    );
  }

  ShopMarketStoreItem copyWith({int? distanceM}) {
    return ShopMarketStoreItem(
      name: name,
      categoryLabel: categoryLabel,
      chipKey: chipKey,
      latitude: latitude,
      longitude: longitude,
      distanceM: distanceM ?? this.distanceM,
      address: address,
      bizesId: bizesId,
      indsLclsCd: indsLclsCd,
      indsLclsNm: indsLclsNm,
      indsMclsCd: indsMclsCd,
      indsMclsNm: indsMclsNm,
      indsSclsCd: indsSclsCd,
      indsSclsNm: indsSclsNm,
      lotAddress: lotAddress,
      sourceAddr: sourceAddr,
      ctprvnCd: ctprvnCd,
      ctprvnNm: ctprvnNm,
      signguCd: signguCd,
      signguNm: signguNm,
      adongCd: adongCd,
      adongNm: adongNm,
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

  final Map<String, ShopMarketInsight> _nearbyCache = {};

  /// Live shop discovery is independent of population analytics and sample assets.
  /// Failed/partial responses are never cached as a successful census.
  Future<ShopMarketInsight> fetchNearby({
    required double latitude,
    required double longitude,
    required int radiusM,
    bool force = false,
  }) async {
    if (!AreaSearchCenter.hasValidPoint(latitude, longitude) ||
        latitude < 33 || latitude > 39 || longitude < 124 || longitude > 132) {
      return ShopMarketInsight.unavailable(reason: 'shop_coords_missing');
    }
    final key = '$latitude|$longitude|$radiusM';
    final cached = _nearbyCache[key];
    if (!force && cached != null && cached.fetchedAt != null &&
        DateTime.now().toUtc().difference(cached.fetchedAt!) < const Duration(minutes: 5)) {
      return cached;
    }
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'get-shop-market',
        body: {
          'action': 'stores',
          'latitude': latitude,
          'longitude': longitude,
          'radius_m': radiusM,
          'category': '전체',
        },
      ).timeout(const Duration(seconds: 30));
      final dynamic data = response.data is String
          ? jsonDecode(response.data as String) : response.data;
      if (data is! Map) throw const FormatException('bad_response');
      final map = Map<String, dynamic>.from(data);
      map.putIfAbsent('latitude', () => latitude);
      map.putIfAbsent('longitude', () => longitude);
      final insight = ShopMarketInsight.fromMap(map);
      if (insight.storesOk && insight.storesComplete) {
        if (_nearbyCache.length >= 12) _nearbyCache.remove(_nearbyCache.keys.first);
        _nearbyCache[key] = insight;
      }
      return insight;
    } catch (_) {
      return ShopMarketInsight.unavailable(
        reason: 'nearby_unavailable',
        centerLatitude: latitude,
        centerLongitude: longitude,
      );
    }
  }

  /// [fallbackAddress]: 샵에 주소/좌표가 없을 때 경영 프로필 주소 등.
  /// 서울 묵시 폴백 없이, 주소 resolve 실패 시 shop_coords_missing.
  /// [overrideLat]/[overrideLng]: GPS 등 임시 중심(캐시 키에 포함 · 실패 시 호출부가 이전 insight 유지).
  Future<ShopMarketInsight> fetch({
    required Shop shop,
    required String category,
    String? admCd,
    String? fallbackAddress,
    int radiusM = 500,
    double? overrideLat,
    double? overrideLng,
  }) async {
    final sid = shop.id.trim();
    final fb = fallbackAddress?.trim() ?? '';
    final oLat = overrideLat;
    final oLng = overrideLng;
    final overrideKey = (oLat != null && oLng != null)
        ? '|g${oLat.toStringAsFixed(4)},${oLng.toStringAsFixed(4)}'
        : '';
    final key =
        '$sid|${category.trim()}|${admCd?.trim() ?? ''}|$fb|$radiusM$overrideKey';
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

    if (oLat != null &&
        oLng != null &&
        oLat.abs() > 0.01 &&
        oLng.abs() > 0.01) {
      working = working.copyWith(latitude: oLat, longitude: oLng);
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
        return _withLocalSnapshot(
          ShopMarketInsight.unavailable(
            reason: 'bad_response',
            centerLatitude: lat,
            centerLongitude: lng,
          ),
          lat: lat,
          lng: lng,
          cacheKey: key,
        );
      }
      map.putIfAbsent('latitude', () => lat);
      map.putIfAbsent('longitude', () => lng);
      return _withLocalSnapshot(
        ShopMarketInsight.fromMap(map),
        lat: lat,
        lng: lng,
        cacheKey: key,
      );
    } catch (e) {
      debugPrint('get-shop-market failed: $e');
      return _withLocalSnapshot(
        ShopMarketInsight.unavailable(
          reason: e.toString(),
          centerLatitude: lat,
          centerLongitude: lng,
        ),
        lat: lat,
        lng: lng,
        cacheKey: key,
      );
    }
  }

  Future<ShopMarketInsight> _withLocalSnapshot(
    ShopMarketInsight insight, {
    required double lat,
    required double lng,
    required String cacheKey,
  }) async {
    final merged = await OurAreaShopSnapshot.mergeIfEmpty(
      insight,
      lat: lat,
      lng: lng,
    );
    if (merged.storeItems.isNotEmpty) {
      _cache = merged;
      _cacheAt = DateTime.now();
      _cacheKey = cacheKey;
    }
    return merged;
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
      return '이 지역의 상권 정보를 불러오지 못했어요.';
    }
    return '이 지역의 상권 정보를 불러오지 못했어요.';
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

