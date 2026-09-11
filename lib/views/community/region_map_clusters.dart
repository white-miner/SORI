import 'package:latlong2/latlong.dart';

import 'region_map_content_pins.dart';

/// Grid cluster + 동일좌표 그룹. spiderfy/가짜 분산 금지.
enum RegionMapOverlayKind { cluster, pinGroup }

class RegionMapOverlay {
  const RegionMapOverlay({
    required this.kind,
    required this.point,
    required this.pins,
    required this.countLabel,
  });

  final RegionMapOverlayKind kind;
  final LatLng point;
  final List<RegionMapPin> pins;

  /// 화면 숫자: 2~99, 100+ → `99+`
  final String countLabel;

  bool get isSingle => pins.length == 1;

  RegionMapPin get sole => pins.first;

  /// mixed cluster 기본은 post(purple) 위계.
  bool get allSeminar => pins.every((p) => p.kind == RegionMapPinKind.seminar);
}

abstract final class RegionMapClusters {
  RegionMapClusters._();

  static String countLabel(int n) {
    if (n <= 0) return '0';
    if (n > 99) return '99+';
    return '$n';
  }

  /// 동일 lat/lng(소수 5자리) 묶음 — 「이 위치의 이야기 N개」용.
  static List<RegionMapOverlay> groupSameCoord(List<RegionMapPin> pins) {
    final map = <String, List<RegionMapPin>>{};
    for (final p in pins) {
      final key =
          '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}';
      (map[key] ??= []).add(p);
    }
    final out = <RegionMapOverlay>[];
    for (final e in map.entries) {
      final list = e.value;
      final first = list.first;
      out.add(
        RegionMapOverlay(
          kind: list.length == 1
              ? RegionMapOverlayKind.pinGroup
              : RegionMapOverlayKind.pinGroup,
          point: LatLng(first.latitude, first.longitude),
          pins: list,
          countLabel: countLabel(list.length),
        ),
      );
    }
    return out;
  }

  /// 저줌: cell 그리드 클러스터. 고줌: 동일좌표 그룹만.
  static List<RegionMapOverlay> build({
    required List<RegionMapPin> pins,
    required double zoom,
  }) {
    if (pins.isEmpty) return const [];
    if (zoom >= 14.5) {
      return groupSameCoord(pins);
    }
    // ~zoom 12–14: ~0.02° cell
    final cell = zoom >= 13.2 ? 0.008 : 0.02;
    final buckets = <String, List<RegionMapPin>>{};
    for (final p in pins) {
      final kx = (p.latitude / cell).floor();
      final ky = (p.longitude / cell).floor();
      final key = '$kx|$ky';
      (buckets[key] ??= []).add(p);
    }
    final out = <RegionMapOverlay>[];
    for (final list in buckets.values) {
      if (list.length == 1) {
        out.addAll(groupSameCoord(list));
        continue;
      }
      var lat = 0.0;
      var lng = 0.0;
      for (final p in list) {
        lat += p.latitude;
        lng += p.longitude;
      }
      lat /= list.length;
      lng /= list.length;
      out.add(
        RegionMapOverlay(
          kind: RegionMapOverlayKind.cluster,
          point: LatLng(lat, lng),
          pins: list,
          countLabel: countLabel(list.length),
        ),
      );
    }
    return out;
  }

  static RegionMapLatLngBounds? boundsOf(List<RegionMapPin> pins) {
    if (pins.isEmpty) return null;
    var minLat = pins.first.latitude;
    var maxLat = pins.first.latitude;
    var minLng = pins.first.longitude;
    var maxLng = pins.first.longitude;
    for (final p in pins) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    if ((maxLat - minLat).abs() < 1e-6) {
      minLat -= 0.002;
      maxLat += 0.002;
    }
    if ((maxLng - minLng).abs() < 1e-6) {
      minLng -= 0.002;
      maxLng += 0.002;
    }
    return RegionMapLatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }
}

class RegionMapLatLngBounds {
  RegionMapLatLngBounds(this.southWest, this.northEast);
  final LatLng southWest;
  final LatLng northEast;

  LatLng get center => LatLng(
        (southWest.latitude + northEast.latitude) / 2,
        (southWest.longitude + northEast.longitude) / 2,
      );
}
