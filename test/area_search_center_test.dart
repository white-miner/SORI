import 'package:flutter_test/flutter_test.dart';
import 'package:sori/features/operation/shop_climate_service.dart';
import 'package:sori/services/shop_market_service.dart';
import 'package:sori/utils/area_search_center.dart';

ShopMarketStoreItem _store({
  required String name,
  required double lat,
  required double lng,
}) {
  return ShopMarketStoreItem(
    name: name,
    categoryLabel: '피부',
    chipKey: 'skin',
    latitude: lat,
    longitude: lng,
    distanceM: 0,
    address: '주소',
  );
}

void main() {
  const centerLat = AreaSearchCenter.defaultLat;
  const centerLng = AreaSearchCenter.defaultLng;
  // ~500m north of default region (1deg lat ≈ 111km)
  const near500mLat = 35.8607;
  const near500mLng = 129.2247;
  // ~2km north
  const mid2kmLat = 35.8742;
  const mid2kmLng = 129.2247;
  // ~8km north
  const far8kmLat = 35.9282;
  const far8kmLng = 129.2247;

  final center = const AreaSearchCenter(
    lat: centerLat,
    lng: centerLng,
    source: AreaSearchSource.defaultRegion,
  );

  List<ShopMarketStoreItem> fixture() => [
        _store(name: 'near500m', lat: near500mLat, lng: near500mLng),
        _store(name: 'mid2km', lat: mid2kmLat, lng: mid2kmLng),
        _store(name: 'far8km', lat: far8kmLat, lng: far8kmLng),
        _store(name: 'invalid', lat: 0, lng: 0),
      ];

  test('default region matches existing climate fallback, not invented Seoul', () {
    expect(AreaSearchCenter.defaultLat, ShopClimateService.gyeongjuLat);
    expect(AreaSearchCenter.defaultLng, ShopClimateService.gyeongjuLng);
    expect(AreaSearchCenter.defaultLat, isNot(37.5665));
  });

  test('currentLocation is the GPS search center map/list/count share', () {
    const lat = 37.5012;
    const lng = 127.0396;
    final here = AreaSearchCenter.currentLocation(lat: lat, lng: lng);
    expect(here.source, AreaSearchSource.gps);
    expect(here.lat, lat);
    expect(here.lng, lng);

    final resolved = AreaSearchCenter.resolve(
      gpsLat: lat,
      gpsLng: lng,
      mapLat: AreaSearchCenter.defaultLat,
      mapLng: AreaSearchCenter.defaultLng,
    );
    expect(resolved.lat, here.lat);
    expect(resolved.lng, here.lng);
    expect(resolved.source, AreaSearchSource.gps);

    expect(
      AreaSearchCenter.currentLocation(lat: 0, lng: 0).source,
      AreaSearchSource.defaultRegion,
    );
  });

  test('resolve: gps > map camera > shop > default region', () {
    expect(
      AreaSearchCenter.resolve(
        gpsLat: 35.1,
        gpsLng: 129.0,
        mapLat: 36.0,
        mapLng: 128.0,
        shopLat: 37.0,
        shopLng: 127.0,
      ).source,
      AreaSearchSource.gps,
    );
    final noGps = AreaSearchCenter.resolve(
      mapLat: 36.1,
      mapLng: 128.1,
      shopLat: 37.0,
      shopLng: 127.0,
    );
    expect(noGps.source, AreaSearchSource.mapCamera);
    expect(noGps.lat, 36.1);

    final shopOnly = AreaSearchCenter.resolve(shopLat: 36.2, shopLng: 128.2);
    expect(shopOnly.source, AreaSearchSource.shopOrInsight);
    expect(shopOnly.lat, 36.2);

    final denied = AreaSearchCenter.resolve();
    expect(denied.source, AreaSearchSource.defaultRegion);
    expect(denied.lat, centerLat);
    expect(denied.lng, centerLng);
  });

  test('location denied still yields a usable center, never empty 0-result null', () {
    final fallback = AreaSearchCenter.resolve(
      gpsLat: null,
      gpsLng: null,
      mapLat: 35.9,
      mapLng: 129.3,
    );
    expect(fallback.source, AreaSearchSource.mapCamera);
    expect(fallback.lat, 35.9);
  });

  test('fixture: 1km=1, 3km=2, 10km=3; invalid excluded from distance', () {
    final items = fixture();
    final at1 = AreaSearchCenter.filter(
      items,
      center: center,
      radiusKm: 1,
      latOf: (s) => s.latitude,
      lngOf: (s) => s.longitude,
      withDistance: (s, m) => s.copyWith(distanceM: m),
    );
    expect(at1.sourceCount, 4);
    expect(at1.validCoordinateCount, 3);
    expect(at1.invalidCoordinateCount, 1);
    expect(at1.inRadiusCount, 1);
    expect(at1.items.single.name, 'near500m');
    expect(at1.items.single.distanceM, greaterThan(0));

    final at3 = AreaSearchCenter.filter(
      items,
      center: center,
      radiusKm: 3,
      latOf: (s) => s.latitude,
      lngOf: (s) => s.longitude,
    );
    expect(at3.inRadiusCount, 2);
    expect(at3.items.map((s) => s.name), ['near500m', 'mid2km']);

    final at10 = AreaSearchCenter.filter(
      items,
      center: center,
      radiusKm: 10,
      latOf: (s) => s.latitude,
      lngOf: (s) => s.longitude,
    );
    expect(at10.inRadiusCount, 3);
    expect(at10.items.map((s) => s.name), ['near500m', 'mid2km', 'far8km']);
  });

  test('A-J diagnostics: radius units, counts, map/list same set', () {
    final diag = AreaSearchCenter.diagnose(
      fixture(),
      search: center,
      mapLat: centerLat,
      mapLng: centerLng,
      radiusKm: 1,
      geoStatus: 'denied',
      latOf: (s) => s.latitude,
      lngOf: (s) => s.longitude,
    );
    expect(diag.radiusKm, 1);
    expect(diag.radiusM, 1000);
    expect(diag.sourceCount, 4);
    expect(diag.validWgs84Count, 3);
    expect(diag.invalidCoordinateCount, 1);
    expect(diag.radiusCountsKm[1], 1);
    expect(diag.radiusCountsKm[3], 2);
    expect(diag.radiusCountsKm[5], 2);
    expect(diag.radiusCountsKm[10], 3);
    expect(diag.listCount, 1);
    expect(diag.markerCount, 1);
    expect(diag.sameCenter, isTrue);
    expect(diag.geoStatus, 'denied');
    expect(diag.report.contains('C radiusUiKm=1.0 filterM=1000'), isTrue);
    // ignore: avoid_print
    print(diag.report);
  });

  test('pointFromMap reads aliases and swapped Korean lng/lat', () {
    expect(
      AreaSearchCenter.pointFromMap({'lat': near500mLat, 'lng': near500mLng}),
      (lat: near500mLat, lng: near500mLng),
    );
    expect(
      AreaSearchCenter.pointFromMap({
        'latitude': near500mLat,
        'longitude': near500mLng,
      }),
      (lat: near500mLat, lng: near500mLng),
    );
    expect(
      AreaSearchCenter.pointFromMap({'x': near500mLng, 'y': near500mLat}),
      (lat: near500mLat, lng: near500mLng),
    );
    expect(
      AreaSearchCenter.pointFromMap({'lat': near500mLng, 'lng': near500mLat}),
      (lat: near500mLat, lng: near500mLng),
    );
    expect(AreaSearchCenter.pointFromMap({'lat': 0, 'lng': 0}), isNull);
    expect(
      AreaSearchCenter.pointFromMap({'x': 198234.1, 'y': 451123.8}),
      isNull,
    );

    final parsed = ShopMarketStoreItem.fromMap({
      'name': '바뀐좌표',
      'lat': near500mLng,
      'lng': near500mLat,
      'distance_m': 12,
    });
    expect(parsed.latitude, near500mLat);
    expect(parsed.longitude, near500mLng);
  });

  test('invalid coordinates never produce a distance label', () {
    expect(
      AreaSearchCenter.distanceMeters(
        centerLat: centerLat,
        centerLng: centerLng,
        pointLat: 0,
        pointLng: 0,
      ),
      isNull,
    );
    expect(AreaSearchCenter.hasValidPoint(0, 0), isFalse);
  });
}
