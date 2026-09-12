import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sori/services/our_area_shop_snapshot.dart';
import 'package:sori/services/shop_market_service.dart';
import 'package:sori/utils/area_search_center.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> fileJson() {
    final raw = File('assets/data/our_area/gyeongju_beauty_shops.json')
        .readAsStringSync();
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  test('gyeongju snapshot has real WGS84 shops inside 1km of default center', () {
    final json = fileJson();
    expect(json['sourceDate'], OurAreaShopSnapshot.sourceDate);
    final items = OurAreaShopSnapshot.parse(
      json,
      centerLat: AreaSearchCenter.defaultLat,
      centerLng: AreaSearchCenter.defaultLng,
    );
    expect(items, isNotEmpty);
    expect(
      items.every(
        (s) => AreaSearchCenter.hasValidPoint(s.latitude, s.longitude),
      ),
      isTrue,
    );
    expect(
      items.where((s) => s.name == '끼있는가위꾼' && s.distanceM < 200),
      isEmpty,
    );

    final center = const AreaSearchCenter(
      lat: AreaSearchCenter.defaultLat,
      lng: AreaSearchCenter.defaultLng,
      source: AreaSearchSource.defaultRegion,
    );
    int countAt(double km) => AreaSearchCenter.filter(
          items,
          center: center,
          radiusKm: km,
          latOf: (s) => s.latitude,
          lngOf: (s) => s.longitude,
        ).items.length;

    final c1 = countAt(1);
    final c3 = countAt(3);
    final c5 = countAt(5);
    final c10 = countAt(10);
    // ignore: avoid_print
    print('D sourceCount=${items.length}');
    // ignore: avoid_print
    print('G 1km=$c1 3km=$c3 5km=$c5 10km=$c10');
    expect(c1, greaterThanOrEqualTo(1));
    expect(c3, greaterThanOrEqualTo(c1));
    expect(c5, greaterThanOrEqualTo(c3));
    expect(c10, greaterThanOrEqualTo(c5));
    expect(c10, items.length);
  });

  test('snapshot is only used near the default region, not Seoul', () {
    expect(
      OurAreaShopSnapshot.covers(
        AreaSearchCenter.defaultLat,
        AreaSearchCenter.defaultLng,
      ),
      isTrue,
    );
    expect(OurAreaShopSnapshot.covers(37.5665, 126.9780), isFalse);
  });

  test('empty Edge insight is filled so map and list share the same shops',
      () async {
    final empty = ShopMarketInsight.unavailable(
      reason: 'stores_empty',
      centerLatitude: AreaSearchCenter.defaultLat,
      centerLongitude: AreaSearchCenter.defaultLng,
    );
    final merged = await OurAreaShopSnapshot.mergeIfEmpty(
      empty,
      lat: AreaSearchCenter.defaultLat,
      lng: AreaSearchCenter.defaultLng,
    );
    expect(merged.storesOk, isTrue);
    expect(merged.storeItems, isNotEmpty);
    expect(merged.sources, contains(OurAreaShopSnapshot.sourceLabel));

    final kept = await OurAreaShopSnapshot.mergeIfEmpty(
      merged,
      lat: AreaSearchCenter.defaultLat,
      lng: AreaSearchCenter.defaultLng,
    );
    expect(kept.storeItems.length, merged.storeItems.length);
  });
}
