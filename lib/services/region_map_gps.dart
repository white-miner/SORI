import 'package:flutter/foundation.dart';
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

  /// `checkPermission()`이 denied여도 [getCurrentPosition]을 생략하지 않는다.
  /// 웹은 query가 prompt 전 denied를 돌려, 실제 프롬프트는 position 요청에 있다.
  static bool shouldSkipPositionFor(LocationPermission permission) => false;

  /// 탭 후에만 호출. 자동 권한·추적·이력 없음.
  static Future<RegionMapGpsResult> oneShot() async {
    try {
      try {
        await Geolocator.requestPermission();
      } catch (_) {
        // 웹 Permissions API는 request가 없거나 실패해도 getCurrentPosition이 프롬프트다.
      }

      if (!kIsWeb) {
        final serviceOn = await Geolocator.isLocationServiceEnabled();
        if (!serviceOn) return const RegionMapGpsResult.failed();
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
    } on PermissionDeniedException {
      return const RegionMapGpsResult.denied();
    } catch (_) {
      return const RegionMapGpsResult.failed();
    }
  }

  /// 이미 허용된 권한일 때만 현재 위치를 조용히 읽는다. 권한 창은 띄우지 않는다.
  /// 샵 카드 거리 칩 표시용 · 저장하지 않는다. 권한 없음/실패는 null.
  static Future<({double lat, double lng})?> grantedPositionOrNull() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      if (!kIsWeb) {
        if (!await Geolocator.isLocationServiceEnabled()) return null;
        final last = await Geolocator.getLastKnownPosition();
        if (last != null &&
            RegionMapCenter.isValidLatLng(last.latitude, last.longitude) &&
            DateTime.now().difference(last.timestamp) <
                const Duration(minutes: 10)) {
          return (lat: last.latitude, lng: last.longitude);
        }
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!RegionMapCenter.isValidLatLng(pos.latitude, pos.longitude)) {
        return null;
      }
      return (lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      return null;
    }
  }
}
