import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sori/utils/region_shop_list_copy.dart';

void main() {
  test('headline and count reuse radius/category/result count', () {
    expect(
      RegionShopListCopy.headline(radiusKm: 0.5, category: '전체'),
      '내 주변 500m 안의 전체 뷰티숍',
    );
    expect(
      RegionShopListCopy.headline(radiusKm: 1, category: '  '),
      '내 주변 1km 안의 전체 뷰티숍',
    );
    expect(
      RegionShopListCopy.headline(radiusKm: 2, category: '피부'),
      '내 주변 2km 안의 피부 뷰티숍',
    );
    expect(RegionShopListCopy.countLine(0), '0곳 발견');
    expect(RegionShopListCopy.countLine(12), '12곳 발견');
    expect(
      RegionShopListCopy.emptyTrueZeroTitle,
      '이 조건에서 찾은 뷰티숍이 없어요.',
    );
    expect(
      RegionShopListCopy.retryGpsLabel,
      '현재 위치 다시 사용',
    );
  });

  test('detail facts hide missing category, distance, and address', () {
    expect(RegionShopListCopy.distanceLabel(0), isNull);
    expect(RegionShopListCopy.distanceLabel(-1), isNull);
    expect(RegionShopListCopy.distanceLabel(180), '180m');
    expect(RegionShopListCopy.distanceLabel(1000), '1km');
    expect(RegionShopListCopy.distanceLabel(1500), '1.5km');
    expect(RegionShopListCopy.visibleText(' 피부 '), '피부');
    expect(RegionShopListCopy.visibleText(''), isNull);
    expect(RegionShopListCopy.visibleText('  '), isNull);
  });

  test('next radius follows the existing chip steps and hides at the top', () {
    expect(RegionShopListCopy.nextRadiusKm(0.5), 1.0);
    expect(RegionShopListCopy.nextRadiusKm(1), 2.0);
    expect(RegionShopListCopy.nextRadiusKm(2), isNull);
    expect(
      RegionShopListCopy.radiusStepsKm,
      <double>[0.5, 1.0, 2.0],
    );
  });

  test('list summary is wired without touching map canvas or explore sheet', () {
    final map = File(
      'lib/views/community/region_nearby_map_section.dart',
    ).readAsStringSync();
    expect(map.contains('RegionShopListCopy.headline'), isTrue);
    expect(map.contains("child: const Text('반경 넓히기')"), isTrue);
    expect(map.contains('_widenRadius'), isTrue);
    expect(map.contains('_ShopDetailFacts'), isTrue);
    expect(map.contains("item.categoryLabel.isEmpty ? '상권'"), isFalse);
    expect(map.contains("child: const Text('지도에서 보기')"), isTrue);
    expect(map.contains('interactionOptions: const InteractionOptions('), isTrue);
    expect(map.contains('AreaSearchCenter'), isTrue);
    expect(map.contains('CircleLayer'), isTrue);
    expect(map.contains('overrideLat: search.lat'), isTrue);
    expect(map.contains('_buildMapCanvas(stores)'), isTrue);
    expect(map.contains('final stores = filter.items'), isTrue);

    final sheet = File(
      'lib/views/community/region_map_explore_sheet.dart',
    ).readAsStringSync();
    expect(sheet.contains('RegionShopListCopy'), isFalse);
    expect(sheet.contains('반경 넓히기'), isFalse);
  });
}
