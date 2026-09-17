import '../models/community_case_item.dart';
import 'geo_distance.dart';

/// PRD v7.8 C3 — 우리 지역 피드 = 중심 좌표 반경 km 안 케이스만.
class RegionFeedFilter {
  RegionFeedFilter._();

  /// [centerLat]/[centerLng] 없으면 빈 목록 (전국 피드와 섞지 않음).
  /// 샵 좌표 없는 케이스는 제외.
  static List<CommunityCaseItem> byRadiusKm(
    List<CommunityCaseItem> items, {
    double? centerLat,
    double? centerLng,
    required double radiusKm,
  }) {
    if (centerLat == null ||
        centerLng == null ||
        centerLat.abs() < 0.01 ||
        centerLng.abs() < 0.01) {
      return const [];
    }
    if (radiusKm <= 0) return const [];

    final out = <CommunityCaseItem>[];
    for (final item in items) {
      final lat = item.shop.latitude;
      final lng = item.shop.longitude;
      if (lat == null || lng == null || lat.abs() < 0.01 || lng.abs() < 0.01) {
        continue;
      }
      if (isWithinRadiusKm(
        centerLat: centerLat,
        centerLng: centerLng,
        pointLat: lat,
        pointLng: lng,
        radiusKm: radiusKm,
      )) {
        out.add(item);
      }
    }
    return out;
  }
}
