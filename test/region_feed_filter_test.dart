import 'package:flutter_test/flutter_test.dart';

import 'package:sori/models/community_case_item.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/models/shop.dart';
import 'package:sori/utils/geo_distance.dart';
import 'package:sori/utils/region_feed_filter.dart';

Shop _shop({required String id, double? lat, double? lng}) => Shop(
      id: id,
      name: '샵$id',
      naverPlaceUrl: '',
      latitude: lat,
      longitude: lng,
    );

CommunityCaseItem _item(Shop shop) => CommunityCaseItem(
      chart: CustomerChart(
        id: 'c-${shop.id}',
        customerId: 'cu',
        shopId: shop.id,
        visitNumber: 1,
        createdAt: DateTime(2026, 1, 1),
      ),
      shop: shop,
    );

void main() {
  test('haversine ~0 for same point', () {
    final m = haversineMeters(
      lat1: 35.85,
      lng1: 129.22,
      lat2: 35.85,
      lng2: 129.22,
    );
    expect(m, lessThan(1));
  });

  test('byRadiusKm keeps near shops only', () {
    const centerLat = 35.8562;
    const centerLng = 129.2247;
    final near = _item(_shop(id: 'near', lat: 35.8565, lng: 129.2250));
    final far = _item(_shop(id: 'far', lat: 37.5665, lng: 126.9780));
    final noCoord = _item(_shop(id: 'none'));

    final out = RegionFeedFilter.byRadiusKm(
      [near, far, noCoord],
      centerLat: centerLat,
      centerLng: centerLng,
      radiusKm: 2,
    );
    expect(out.map((e) => e.shop.id), ['near']);
  });

  test('byRadiusKm empty when center missing', () {
    final near = _item(_shop(id: 'near', lat: 35.85, lng: 129.22));
    final out = RegionFeedFilter.byRadiusKm(
      [near],
      centerLat: null,
      centerLng: null,
      radiusKm: 1,
    );
    expect(out, isEmpty);
  });
}
