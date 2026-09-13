import 'dart:convert';

import 'package:flutter/services.dart';

import '../utils/area_search_center.dart';
import 'shop_market_service.dart';

class OurAreaSnapshotRegion {
  const OurAreaSnapshotRegion({
    required this.id,
    required this.assetPath,
    required this.lat,
    required this.lng,
    required this.sourceDate,
    this.coverRadiusKm = OurAreaShopSnapshot.coverRadiusKm,
  });

  final String id;
  final String assetPath;
  final double lat;
  final double lng;
  final String sourceDate;
  final double coverRadiusKm;

  bool covers(double lat, double lng) {
    final m = AreaSearchCenter.distanceMeters(
      centerLat: this.lat,
      centerLng: this.lng,
      pointLat: lat,
      pointLng: lng,
    );
    return m != null && m <= coverRadiusKm * 1000;
  }
}

/// 우리 지역 뷰티 업소 스냅샷. 경주 예시 + 실샵 성건동.
/// Edge `get-shop-market`이 0건일 때만 목록/마커에 합친다.
abstract final class OurAreaShopSnapshot {
  static const assetPath = 'assets/data/our_area/gyeongju_beauty_shops.json';
  static const seonggeonAssetPath =
      'assets/data/our_area/gyeongju_seonggeon_beauty_shops.json';
  static const sourceLabel = '우리 지역 공공데이터 스냅샷';
  static const coverRadiusKm = 25.0;

  static const gyeongju = OurAreaSnapshotRegion(
    id: 'gyeongju',
    assetPath: assetPath,
    lat: AreaSearchCenter.defaultLat,
    lng: AreaSearchCenter.defaultLng,
    sourceDate: '2026-09-12',
  );

  /// 실샵/시사회 대상 행정동(경주시 성건동) 상권 중심.
  static const seonggeon = OurAreaSnapshotRegion(
    id: 'gyeongju-seonggeon',
    assetPath: seonggeonAssetPath,
    lat: 35.8534,
    lng: 129.2087,
    sourceDate: '2026-09-13',
  );

  static const regions = <OurAreaSnapshotRegion>[gyeongju, seonggeon];

  /// JSON `sourceDate` 중 가장 최신. 모르면 추측하지 않는다.
  static const sourceDate = '2026-09-13';

  static const _labels = <String, String>{
    'hair': '헤어',
    'barber': '바버',
    'nail': '네일',
    'skin': '피부',
    'tattoo': '타투',
    'makeup': '메이크업',
    'other': '기타 뷰티',
  };

  static bool covers(double lat, double lng) =>
      regions.any((region) => region.covers(lat, lng));

  static List<ShopMarketStoreItem> parse(
    Map<String, dynamic> json, {
    required double centerLat,
    required double centerLng,
  }) {
    final shops = json['shops'];
    if (shops is! List) return const [];
    final out = <ShopMarketStoreItem>[];
    for (final raw in shops) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final status = '${map['status'] ?? ''}'.trim();
      if (status.isNotEmpty && status != 'operating') continue;
      final point = AreaSearchCenter.pointFromMap(map);
      if (point == null) continue;
      final name = '${map['name'] ?? ''}'.trim();
      if (name.isEmpty) continue;
      final chip = '${map['category'] ?? 'other'}'.trim();
      final chipKey = _labels.containsKey(chip) ? chip : 'other';
      final distance = AreaSearchCenter.distanceMeters(
            centerLat: centerLat,
            centerLng: centerLng,
            pointLat: point.lat,
            pointLng: point.lng,
          ) ??
          0;
      out.add(
        ShopMarketStoreItem(
          name: name,
          categoryLabel: _labels[chipKey] ?? '기타 뷰티',
          chipKey: chipKey,
          latitude: point.lat,
          longitude: point.lng,
          distanceM: distance,
          address: '${map['address'] ?? ''}'.trim(),
        ),
      );
    }
    out.sort((a, b) => a.distanceM.compareTo(b.distanceM));
    return out;
  }

  static Future<List<ShopMarketStoreItem>> loadNear({
    required double lat,
    required double lng,
  }) async {
    if (!covers(lat, lng)) return const [];
    final seen = <String>{};
    final out = <ShopMarketStoreItem>[];
    for (final region in regions) {
      if (!region.covers(lat, lng)) continue;
      final raw = await rootBundle.loadString(region.assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) continue;
      final items = parse(
        Map<String, dynamic>.from(decoded),
        centerLat: lat,
        centerLng: lng,
      );
      for (final item in items) {
        final key =
            '${item.name}|${item.latitude.toStringAsFixed(5)}|${item.longitude.toStringAsFixed(5)}';
        if (seen.add(key)) out.add(item);
      }
    }
    out.sort((a, b) => a.distanceM.compareTo(b.distanceM));
    return out;
  }

  static Future<ShopMarketInsight> mergeIfEmpty(
    ShopMarketInsight insight, {
    required double lat,
    required double lng,
  }) async {
    if (insight.storeItems.isNotEmpty) return insight;
    final items = await loadNear(lat: lat, lng: lng);
    if (items.isEmpty) return insight;
    return insight.withFallbackStores(items);
  }
}
