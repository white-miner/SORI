import 'dart:convert';

import 'package:flutter/services.dart';

import '../utils/area_search_center.dart';
import 'shop_market_service.dart';

/// 실샵 대상 지역(경주) 뷰티 업소 스냅샷.
/// Edge `get-shop-market`이 0건일 때만 목록/마커에 합친다.
abstract final class OurAreaShopSnapshot {
  static const assetPath = 'assets/data/our_area/gyeongju_beauty_shops.json';
  static const sourceLabel = '우리 지역 공공데이터 스냅샷';
  static const coverRadiusKm = 25.0;

  static const _labels = <String, String>{
    'hair': '헤어',
    'barber': '바버',
    'nail': '네일',
    'skin': '피부',
    'tattoo': '타투',
    'makeup': '메이크업',
    'other': '기타 뷰티',
  };

  static bool covers(double lat, double lng) {
    final m = AreaSearchCenter.distanceMeters(
      centerLat: AreaSearchCenter.defaultLat,
      centerLng: AreaSearchCenter.defaultLng,
      pointLat: lat,
      pointLng: lng,
    );
    return m != null && m <= coverRadiusKm * 1000;
  }

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
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const [];
    return parse(
      Map<String, dynamic>.from(decoded),
      centerLat: lat,
      centerLng: lng,
    );
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
