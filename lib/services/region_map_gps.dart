import 'package:geolocator/geolocator.dart';

import '../views/community/region_map_center.dart';

/// Phase C.1 — 우리지역 맵 GPS 1회 조회. 좌표를 디스크/서버에 저장하지 않는다.
enum RegionMapGpsOutcome { ok, denied, failed }

class RegionMapGpsResult {
  const RegionMapGpsResult._(this.outcome, {this.lat, this.lng});

  const RegionMapGpsResult.ok(double lat, double lng)
      : this._(RegionMapGpsOutcome.ok, lat: lat, lng: lng);

  const RegionMapGpsResult.denied() : this._(RegionMapGpsOutcome.denied);

  const RegionMapGpsResult.failed() : this._(RegionMapGpsOutcome.failed);

  final RegionMapGpsOutcome outcome;
  final double? lat;
  final double? lng;
}

abstract final class RegionMapGps {
  RegionMapGps._();

  /// 탭 후에만 호출. 자동 권한·추적·이력 없음.
  static Future<RegionMapGpsResult> oneShot() async {
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) return const RegionMapGpsResult.failed();

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const RegionMapGpsResult.denied();
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!RegionMapCenter.isValidLatLng(pos.latitude, pos.longitude)) {
        return const RegionMapGpsResult.failed();
      }
      return RegionMapGpsResult.ok(pos.latitude, pos.longitude);
    } catch (_) {
      return const RegionMapGpsResult.failed();
    }
  }
}
