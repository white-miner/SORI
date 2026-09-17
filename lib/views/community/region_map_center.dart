/// Phase C — 우리지역 맵 중심 후보 (순수). GPS는 패키지 없이 호출부에서만 주입.
abstract final class RegionMapCenter {
  RegionMapCenter._();

  static bool isValidLatLng(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat.isNaN || lng.isNaN || lat.isInfinite || lng.isInfinite) {
      return false;
    }
    if (lat.abs() < 0.01 && lng.abs() < 0.01) return false; // 0,0
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
    return true;
  }

  /// 우선순위: GPS → insight/지오코딩 중심 → Shop 저장 좌표.
  /// 모두 실패 시 null (가짜 서울 금지).
  static ({double lat, double lng})? resolve({
    double? gpsLat,
    double? gpsLng,
    double? insightLat,
    double? insightLng,
    double? shopLat,
    double? shopLng,
  }) {
    if (isValidLatLng(gpsLat, gpsLng)) {
      return (lat: gpsLat!, lng: gpsLng!);
    }
    if (isValidLatLng(insightLat, insightLng)) {
      return (lat: insightLat!, lng: insightLng!);
    }
    if (isValidLatLng(shopLat, shopLng)) {
      return (lat: shopLat!, lng: shopLng!);
    }
    return null;
  }
}
