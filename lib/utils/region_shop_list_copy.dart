/// 우리 지역 업체 목록 헤더·빈 결과 카피. 반경 단계는 맵 칩과 동일하다.
abstract final class RegionShopListCopy {
  static const radiusStepsKm = <double>[0.5, 1.0, 2.0];

  static String radiusLabel(double km) {
    if (km < 1) return '${(km * 1000).round()}m';
    if (km == km.roundToDouble()) return '${km.toInt()}km';
    return '${km}km';
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
