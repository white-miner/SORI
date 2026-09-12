import 'area_search_center.dart';

/// 우리 지역 업체 목록 헤더·빈 결과 카피. 반경 단계는 맵 칩과 동일하다.
abstract final class RegionShopListCopy {
  static const radiusStepsKm = <double>[0.5, 1.0, 2.0, 3.0, 5.0, 10.0];

  static String radiusLabel(double km) {
    if (km < 1) return '${(km * 1000).round()}m';
    if (km == km.roundToDouble()) return '${km.toInt()}km';
    return '${km}km';
  }

  static double mapZoom(double km) {
    if (km <= 0.5) return 15.2;
    if (km <= 1) return 14.2;
    if (km <= 2) return 13.2;
    if (km <= 3) return 12.4;
    if (km <= 5) return 11.8;
    return 11.0;
  }

  static String categoryLabel(String? raw) {
    final value = raw?.trim() ?? '';
    return value.isEmpty ? '전체' : value;
  }

  static String headline({
    required double radiusKm,
    String? category,
  }) {
    return '내 주변 ${radiusLabel(radiusKm)} 안의 ${categoryLabel(category)} 뷰티숍';
  }

  static String countLine(int count) => '$count곳 발견';

  static String conditionLine({
    required String searchBasis,
    required double radiusKm,
    String? category,
  }) {
    return '$searchBasis · ${radiusLabel(radiusKm)} · ${categoryLabel(category)}';
  }

  static String? compositionLine(Iterable<({String label, int count})> mix) {
    final parts = [
      for (final row in mix)
        if (row.count > 0) '${row.label} ${row.count}곳',
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  static String? topCategoryLine(String? label) {
    final value = visibleText(label);
    if (value == null) return null;
    return '가장 많은 업종은 $value';
  }

  static const emptyTrueZeroTitle = '이 조건에서 찾은 뷰티숍이 없어요.';
  static const emptyTrueZeroHint = '반경을 넓혀서 다시 찾아보세요.';
  static const emptyLocationTitle = '현재 위치 기준으로 업체를 찾지 못했어요.';
  static const emptyLocationHint = '현재 위치를 사용할 수 없어 지도 중심으로 찾고 있어요.';
  static const retryGpsLabel = '현재 위치 다시 사용';
  static const searchFromMapLabel = '지도 중심으로 찾기';

  static String searchBasis(AreaSearchSource source) {
    switch (source) {
      case AreaSearchSource.gps:
        return '현재 위치 기준';
      case AreaSearchSource.mapCamera:
        return '지도 중심 기준';
      case AreaSearchSource.shopOrInsight:
        return '샵 위치 기준';
      case AreaSearchSource.defaultRegion:
        return '기본 지역 기준';
    }
  }

  static String locationUnavailableBanner(AreaSearchSource fallback) {
    return '현재 위치를 사용할 수 없어 ${searchBasis(fallback)}으로 찾고 있어요.';
  }

  /// 0 이하는 미기록으로 보고 숨긴다.
  static String? distanceLabel(int meters) {
    if (meters <= 0) return null;
    if (meters < 1000) return '${meters}m';
    final km = meters / 1000;
    if (km == km.roundToDouble()) return '${km.toInt()}km';
    return '${km.toStringAsFixed(1)}km';
  }

  static String? visibleText(String? raw) {
    final value = raw?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  static double? nextRadiusKm(
    double current, {
    List<double> steps = radiusStepsKm,
  }) {
    for (final km in steps) {
      if (km > current + 0.0001) return km;
    }
    return null;
  }
}
