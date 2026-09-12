import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sori/services/our_area_shop_snapshot.dart';
import 'package:sori/utils/area_search_center.dart';
import 'package:sori/utils/our_area_category.dart';

void main() {
  test('public raw labels map onto the small SORI category set', () {
    expect(OurAreaCategory.mapRaw('두발 미용업'), OurAreaCategory.hair);
    expect(OurAreaCategory.mapRaw('헤어샵'), OurAreaCategory.hair);
    expect(OurAreaCategory.mapRaw('일반이용업'), OurAreaCategory.barber);
    expect(OurAreaCategory.mapRaw('네일아트'), OurAreaCategory.nail);
    expect(OurAreaCategory.mapRaw('피부미용업'), OurAreaCategory.skin);
    expect(OurAreaCategory.mapRaw('에스테틱'), OurAreaCategory.skin);
    expect(OurAreaCategory.mapRaw('타투'), OurAreaCategory.tattoo);
    expect(OurAreaCategory.mapRaw('카페'), OurAreaCategory.other);
    expect(OurAreaCategory.mapRaw('nail'), OurAreaCategory.nail);
    expect(OurAreaCategory.labelOf(OurAreaCategory.hair), '헤어');
  });

  test('selected category quietly drops unmapped other shops', () {
    expect(
      OurAreaCategory.matches(
        selected: OurAreaCategory.hair,
        chipKey: 'other',
        categoryLabel: '카페',
      ),
      isFalse,
    );
    expect(
      OurAreaCategory.matches(
        selected: OurAreaCategory.hair,
        chipKey: 'hair',
        categoryLabel: '두발 미용업',
      ),
      isTrue,
    );
    expect(
      OurAreaCategory.matches(
        selected: OurAreaCategory.all,
        chipKey: 'other',
        categoryLabel: '카페',
      ),
      isTrue,
    );
    expect(
      OurAreaCategory.matches(
        selected: OurAreaCategory.nail,
        chipKey: '',
        categoryLabel: '네일숍',
      ),
      isTrue,
    );
  });

  test('snapshot hair vs nail counts change with the same center', () {
    final raw = jsonDecode(
      File('assets/data/our_area/gyeongju_beauty_shops.json').readAsStringSync(),
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
    final hair = in1km
        .where(
          (s) => OurAreaCategory.matches(
            selected: OurAreaCategory.hair,
            chipKey: s.chipKey,
            categoryLabel: s.categoryLabel,
          ),
        )
        .length;
    final nail = in1km
        .where(
          (s) => OurAreaCategory.matches(
            selected: OurAreaCategory.nail,
            chipKey: s.chipKey,
            categoryLabel: s.categoryLabel,
          ),
        )
        .length;
    expect(in1km, isNotEmpty);
    expect(hair + nail, lessThanOrEqualTo(in1km.length));
    expect(hair, greaterThan(0));
    expect(nail, greaterThan(0));
    expect(hair, isNot(nail));
  });
}
