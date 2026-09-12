import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sori/services/our_area_shop_snapshot.dart';
import 'package:sori/utils/area_search_center.dart';
import 'package:sori/utils/our_area_category.dart';
import 'package:sori/utils/our_area_radius_insight.dart';

void main() {
  test('1km gyeongju results show hair as the top category without revenue', () {
    final raw = jsonDecode(
      File(OurAreaShopSnapshot.assetPath).readAsStringSync(),
    ) as Map<String, dynamic>;
    final items = OurAreaShopSnapshot.parse(
      raw,
      centerLat: AreaSearchCenter.defaultLat,
      centerLng: AreaSearchCenter.defaultLng,
    );
    final in1km = AreaSearchCenter.filter(
      items,
      center: const AreaSearchCenter(
        lat: AreaSearchCenter.defaultLat,
        lng: AreaSearchCenter.defaultLng,
        source: AreaSearchSource.defaultRegion,
      ),
      radiusKm: 1,
      latOf: (s) => s.latitude,
      lngOf: (s) => s.longitude,
    ).items;
    final insight = OurAreaRadiusInsight.fromMappedKeys(
      in1km.map((s) => s.chipKey),
    );
    expect(insight.total, 8);
    expect(insight.top?.key, OurAreaCategory.hair);
    expect(insight.top?.count, 7);
    expect(
      insight.mix.map((row) => '${row.key}:${row.count}').toList(),
      <String>['hair:7', 'nail:1'],
    );
  });

  test('empty radius results do not invent a top category', () {
    const insight = OurAreaRadiusInsight.empty;
    expect(insight.isEmpty, isTrue);
    expect(insight.top, isNull);
  });
}
