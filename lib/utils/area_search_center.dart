import '../views/community/region_map_center.dart';
import 'geo_distance.dart';

/// 우리 지역 탐색 중심 SSOT.
/// 지도 카메라 · 반경 원 · 목록 필터 · 결과 요약이 이 값만 본다.
enum AreaSearchSource { gps, mapCamera, shopOrInsight, defaultRegion }

class AreaSearchCenter {
  const AreaSearchCenter({
    required this.lat,
    required this.lng,
    required this.source,
  });

  final double lat;
  final double lng;
  final AreaSearchSource source;

  /// 기존 기본 지역 중심. [ShopClimateService.gyeongjuLat/Lng]와 동일.
  static const defaultLat = 35.8562;
  static const defaultLng = 129.2247;

  static const defaultRegion = AreaSearchCenter(
    lat: defaultLat,
    lng: defaultLng,
    source: AreaSearchSource.defaultRegion,
  );

  /// 사용자 GPS 한 점. [source]는 gps(현재 위치). 지도·원·목록·카운트가 이 좌표만 본다.
  static AreaSearchCenter currentLocation({
    required double lat,
    required double lng,
  }) {
    if (!RegionMapCenter.isValidLatLng(lat, lng)) return defaultRegion;
    return AreaSearchCenter(
      lat: lat,
      lng: lng,
      source: AreaSearchSource.gps,
    );
  }

  /// GPS → 지도 중심 → 샵/인사이트 → 기본 지역. 조용한 null(0건)을 만들지 않는다.
  static AreaSearchCenter resolve({
    double? gpsLat,
    double? gpsLng,
    double? mapLat,
    double? mapLng,
    double? insightLat,
    double? insightLng,
    double? shopLat,
    double? shopLng,
  }) {
    if (RegionMapCenter.isValidLatLng(gpsLat, gpsLng)) {
      return AreaSearchCenter(
        lat: gpsLat!,
        lng: gpsLng!,
        source: AreaSearchSource.gps,
      );
    }
    if (RegionMapCenter.isValidLatLng(mapLat, mapLng)) {
      return AreaSearchCenter(
        lat: mapLat!,
        lng: mapLng!,
        source: AreaSearchSource.mapCamera,
      );
    }
    final shop = RegionMapCenter.resolve(
      insightLat: insightLat,
      insightLng: insightLng,
      shopLat: shopLat,
      shopLng: shopLng,
    );
    if (shop != null) {
      return AreaSearchCenter(
        lat: shop.lat,
        lng: shop.lng,
        source: AreaSearchSource.shopOrInsight,
      );
    }
    return defaultRegion;
  }

  /// public data / Edge 응답의 lat-lng · x/y · 순서 바뀜을 한곳에서 읽는다.
  static ({double lat, double lng})? pointFromMap(Map<String, dynamic> map) {
    var lat = _asDouble(
      map['lat'] ?? map['latitude'] ?? map['y'] ?? map['ycord'] ?? map['cy'],
    );
    var lng = _asDouble(
      map['lng'] ??
          map['lon'] ??
          map['longitude'] ??
          map['x'] ??
          map['xcord'] ??
          map['cx'],
    );
    if (lat == null || lng == null) return null;
    // 한국 범위에서 lat/lng가 뒤집힌 경우만 교정한다.
    if (lat >= 124 && lat <= 132 && lng >= 33 && lng <= 39) {
      final swapped = lat;
      lat = lng;
      lng = swapped;
    }
    if (!RegionMapCenter.isValidLatLng(lat, lng)) return null;
    return (lat: lat, lng: lng);
  }

  static bool hasValidPoint(double? lat, double? lng) =>
      RegionMapCenter.isValidLatLng(lat, lng);

  static int? distanceMeters({
    required double centerLat,
    required double centerLng,
    required double? pointLat,
    required double? pointLng,
  }) {
    if (!hasValidPoint(pointLat, pointLng)) return null;
    return haversineMeters(
      lat1: centerLat,
      lng1: centerLng,
      lat2: pointLat!,
      lng2: pointLng!,
    ).round();
  }

  static AreaSearchFilterResult<T> filter<T>(
    Iterable<T> items, {
    required AreaSearchCenter center,
    required double radiusKm,
    required double? Function(T item) latOf,
    required double? Function(T item) lngOf,
    T Function(T item, int distanceM)? withDistance,
  }) {
    final sourceCount = items.length;
    var validCoordinateCount = 0;
    final kept = <T>[];
    for (final item in items) {
      final lat = latOf(item);
      final lng = lngOf(item);
      if (!hasValidPoint(lat, lng)) continue;
      validCoordinateCount++;
      final meters = distanceMeters(
        centerLat: center.lat,
        centerLng: center.lng,
        pointLat: lat,
        pointLng: lng,
      );
      if (meters == null) continue;
      if (!isWithinRadiusKm(
        centerLat: center.lat,
        centerLng: center.lng,
        pointLat: lat!,
        pointLng: lng!,
        radiusKm: radiusKm,
      )) {
        continue;
      }
      kept.add(withDistance == null ? item : withDistance(item, meters));
    }
    return AreaSearchFilterResult<T>(
      sourceCount: sourceCount,
      validCoordinateCount: validCoordinateCount,
      invalidCoordinateCount: sourceCount - validCoordinateCount,
      inRadiusCount: kept.length,
      items: kept,
    );
  }

  /// Deploy 32 진단 A–J. UI km → filter m 변환을 명시한다.
  static AreaSearchDiagnostics diagnose<T>(
    Iterable<T> items, {
    required AreaSearchCenter search,
    double? mapLat,
    double? mapLng,
    required double radiusKm,
    required String geoStatus,
    required double? Function(T item) latOf,
    required double? Function(T item) lngOf,
  }) {
    final current = filter(
      items,
      center: search,
      radiusKm: radiusKm,
      latOf: latOf,
      lngOf: lngOf,
    );
    final probes = <double, int>{
      for (final km in AreaSearchDiagnostics.probeRadiiKm)
        km: filter(
          items,
          center: search,
          radiusKm: km,
          latOf: latOf,
          lngOf: lngOf,
        ).inRadiusCount,
    };
    return AreaSearchDiagnostics(
      searchLat: search.lat,
      searchLng: search.lng,
      searchSource: search.source,
      mapLat: mapLat,
      mapLng: mapLng,
      radiusKm: radiusKm,
      radiusM: (radiusKm * 1000).round(),
      sourceCount: current.sourceCount,
      validWgs84Count: current.validCoordinateCount,
      invalidCoordinateCount: current.invalidCoordinateCount,
      radiusCountsKm: probes,
      listCount: current.inRadiusCount,
      markerCount: current.inRadiusCount,
      sameCenter: mapLat == null ||
          mapLng == null ||
          ((mapLat - search.lat).abs() < 1e-7 &&
              (mapLng - search.lng).abs() < 1e-7) ||
          search.source == AreaSearchSource.mapCamera,
      geoStatus: geoStatus,
    );
  }

  static double? _asDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse('$raw');
  }
}

class AreaSearchFilterResult<T> {
  const AreaSearchFilterResult({
    required this.sourceCount,
    required this.validCoordinateCount,
    required this.invalidCoordinateCount,
    required this.inRadiusCount,
    required this.items,
  });

  final int sourceCount;
  final int validCoordinateCount;
  final int invalidCoordinateCount;
  final int inRadiusCount;
  final List<T> items;
}

/// 15분 진단 계약 A–J. 추측 금지, 이 숫자만 보고한다.
class AreaSearchDiagnostics {
  const AreaSearchDiagnostics({
    required this.searchLat,
    required this.searchLng,
    required this.searchSource,
    required this.mapLat,
    required this.mapLng,
    required this.radiusKm,
    required this.radiusM,
    required this.sourceCount,
    required this.validWgs84Count,
    required this.invalidCoordinateCount,
    required this.radiusCountsKm,
    required this.listCount,
    required this.markerCount,
    required this.sameCenter,
    required this.geoStatus,
  });

  static const probeRadiiKm = <double>[1, 3, 5, 10];

  final double searchLat;
  final double searchLng;
  final AreaSearchSource searchSource;
  final double? mapLat;
  final double? mapLng;
  final double radiusKm;
  final int radiusM;
  final int sourceCount;
  final int validWgs84Count;
  final int invalidCoordinateCount;
  final Map<double, int> radiusCountsKm;
  final int listCount;
  final int markerCount;
  final bool sameCenter;
  final String geoStatus;

  String get report =>
      'A search=${searchLat.toStringAsFixed(5)},${searchLng.toStringAsFixed(5)} source=${searchSource.name}\n'
      'B map=${mapLat?.toStringAsFixed(5)},${mapLng?.toStringAsFixed(5)}\n'
      'C radiusUiKm=$radiusKm filterM=$radiusM\n'
      'D sourceCount=$sourceCount\n'
      'E validWgs84=$validWgs84Count\n'
      'F invalid=$invalidCoordinateCount\n'
      'G 1km=${radiusCountsKm[1]} 3km=${radiusCountsKm[3]} 5km=${radiusCountsKm[5]} 10km=${radiusCountsKm[10]}\n'
      'H listCount=$listCount\n'
      'I geo=$geoStatus\n'
      'J sameCenter=$sameCenter list==marker=${listCount == markerCount}';
}
