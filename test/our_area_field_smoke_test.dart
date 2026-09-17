import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sori/services/our_area_shop_snapshot.dart';
import 'package:sori/utils/area_search_center.dart';
import 'package:sori/utils/naver_map_links.dart';
import 'package:sori/utils/our_area_category.dart';
import 'package:sori/utils/region_shop_list_copy.dart';

void main() {
  Map<String, dynamic> snapshotJson() {
    return jsonDecode(
      File(OurAreaShopSnapshot.assetPath).readAsStringSync(),
    ) as Map<String, dynamic>;
  }

  test('field smoke: 1/3/5/10km counts, map=list, category, Naver handoff', () {
    final items = OurAreaShopSnapshot.parse(
      snapshotJson(),
      centerLat: AreaSearchCenter.defaultLat,
      centerLng: AreaSearchCenter.defaultLng,
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
    print('field 1km=$c1 3km=$c3 5km=$c5 10km=$c10 list==marker');
    expect(c1, greaterThanOrEqualTo(1));
    expect(c3, greaterThanOrEqualTo(c1));
    expect(c5, greaterThanOrEqualTo(c3));
    expect(c10, greaterThanOrEqualTo(c5));
    expect(c3, greaterThan(c1));

    final at1 = AreaSearchCenter.filter(
      items,
      center: center,
      radiusKm: 1,
      latOf: (s) => s.latitude,
      lngOf: (s) => s.longitude,
    ).items;
    final hair = at1
        .where(
          (s) => OurAreaCategory.matches(
            selected: OurAreaCategory.hair,
            chipKey: s.chipKey,
            categoryLabel: s.categoryLabel,
          ),
        )
        .toList();
    expect(hair.length, lessThan(at1.length));
    expect(hair, isNotEmpty);

    final sample = at1.first;
    expect(sample.name, isNotEmpty);
    final uri = NaverMapLinks.uri(
      name: sample.name,
      address: sample.address,
      latitude: sample.latitude,
      longitude: sample.longitude,
    );
    expect(uri, isNotNull);

    expect(RegionShopListCopy.radiusStepsKm, containsAll(<double>[1, 3, 5, 10]));
    expect(RegionShopListCopy.mapZoom(1), 14.2);
    expect(RegionShopListCopy.mapZoom(10), 11.0);

    final map = File('lib/views/community/region_nearby_map_section.dart')
        .readAsStringSync();
    expect(map.contains('_visibleStores'), isTrue);
    expect(map.contains('_buildMapCanvas(stores)'), isTrue);
    expect(map.contains('OurAreaCategory.selectableKeys'), isTrue);
    expect(map.contains('interactionOptions: const InteractionOptions('), isTrue);
    expect(
      File('lib/views/community/region_map_explore_sheet.dart')
          .readAsStringSync()
          .contains('OurAreaCategory'),
      isFalse,
    );
  });
}
