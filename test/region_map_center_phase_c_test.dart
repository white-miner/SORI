import 'package:flutter_test/flutter_test.dart';

import 'package:sori/views/community/region_map_center.dart';

void main() {
  test('rejects 0,0 and invalid ranges', () {
    expect(RegionMapCenter.isValidLatLng(0, 0), isFalse);
    expect(RegionMapCenter.isValidLatLng(91, 127), isFalse);
    expect(RegionMapCenter.isValidLatLng(37.5, 127.0), isTrue);
  });

  test('priority gps > insight > shop; never invents seoul', () {
    expect(
      RegionMapCenter.resolve(
        gpsLat: 35.1,
        gpsLng: 129.0,
        insightLat: 37.5,
        insightLng: 127.0,
        shopLat: 36.0,
        shopLng: 128.0,
      ),
      (lat: 35.1, lng: 129.0),
    );
    expect(
      RegionMapCenter.resolve(
        insightLat: 37.5,
        insightLng: 127.0,
        shopLat: 36.0,
        shopLng: 128.0,
      ),
      (lat: 37.5, lng: 127.0),
    );
    expect(
      RegionMapCenter.resolve(shopLat: 36.0, shopLng: 128.0),
      (lat: 36.0, lng: 128.0),
    );
    expect(RegionMapCenter.resolve(), isNull);
  });

  test('gps failure does not clear existing shop center candidates', () {
    // Caller must not pass gps when failed; shop/insight remain.
    final kept = RegionMapCenter.resolve(
      gpsLat: null,
      gpsLng: null,
      shopLat: 37.5,
      shopLng: 127.0,
    );
    expect(kept?.lat, 37.5);
  });
}
