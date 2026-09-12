import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sori/utils/area_search_center.dart';
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
    expect(
      RegionShopListCopy.searchBasis(AreaSearchSource.gps),
      '현재 위치 기준',
    );
    expect(
      RegionShopListCopy.searchBasis(AreaSearchSource.mapCamera),
      '지도 중심 기준',
    );
    expect(
      RegionShopListCopy.searchBasis(AreaSearchSource.defaultRegion),
      '기본 지역 기준',
    );
    expect(
      RegionShopListCopy.locationUnavailableBanner(AreaSearchSource.mapCamera),
      '현재 위치를 사용할 수 없어 지도 중심 기준으로 찾고 있어요.',
    );
    expect(
      RegionShopListCopy.emptyLocationHint,
      '현재 위치를 사용할 수 없어 지도 중심으로 찾고 있어요.',
    );
    expect(
      RegionShopListCopy.conditionLine(
        searchBasis: '기본 지역 기준',
        radiusKm: 1,
        category: '전체',
      ),
      '기본 지역 기준 · 1km · 전체',
    );
    expect(
      RegionShopListCopy.compositionLine([
        (label: '헤어', count: 7),
        (label: '네일', count: 1),
      ]),
      '헤어 7곳 · 네일 1곳',
    );
    expect(RegionShopListCopy.topCategoryLine('헤어'), '가장 많은 업종은 헤어');
    expect(RegionShopListCopy.topCategoryLine(''), isNull);
    expect(
      RegionShopListCopy.provenanceLine(
        sources: const ['우리 지역 공공데이터 스냅샷', '소상공인시장진흥공단 상가(상권)정보'],
        snapshotDate: '2026-09-12',
      ),
      '로컬 스냅샷 · 기준일 2026-09-12',
    );
    expect(
      RegionShopListCopy.provenanceLine(
        sources: const ['소상공인시장진흥공단 상가(상권)정보'],
      ),
      '소상공인시장진흥공단 상가(상권)정보 · 기준일 없음',
    );
    expect(
      RegionShopListCopy.provenanceLine(sources: const []),
      '로컬 데이터 · 기준일 없음',
    );
    expect(
      RegionShopListCopy.provenanceLine(
        sources: const ['우리 지역 공공데이터 스냅샷'],
        snapshotDate: '',
      ),
      '로컬 스냅샷 · 기준일 없음',
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
    expect(RegionShopListCopy.nextRadiusKm(2), 3.0);
    expect(RegionShopListCopy.nextRadiusKm(3), 5.0);
    expect(RegionShopListCopy.nextRadiusKm(5), 10.0);
    expect(RegionShopListCopy.nextRadiusKm(10), isNull);
    expect(
      RegionShopListCopy.radiusStepsKm,
      <double>[0.5, 1.0, 2.0, 3.0, 5.0, 10.0],
    );
  });

  test('list summary is wired without touching map canvas or explore sheet', () {
    final map = File(
      'lib/views/community/region_nearby_map_section.dart',
    ).readAsStringSync();
    expect(map.contains('RegionShopListCopy.headline'), isTrue);
    expect(map.contains('RegionShopListCopy.searchBasis'), isTrue);
    expect(map.contains('OurAreaRadiusInsight.fromMappedKeys'), isTrue);
    expect(map.contains("key: const Key('region-shop-insight')"), isTrue);
    expect(map.contains("key: const Key('region-shop-insight-mix')"), isTrue);
    expect(map.contains("key: const Key('region-shop-insight-top')"), isTrue);
    expect(map.contains("key: const Key('region-shop-insight-condition')"), isTrue);
    expect(map.contains("key: const Key('region-shop-provenance')"), isTrue);
    expect(map.contains('RegionShopListCopy.provenanceLine'), isTrue);
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
    expect(map.contains('final stores = _visibleStores'), isTrue);
    expect(map.contains('OurAreaCategory.matches'), isTrue);

    final sheet = File(
      'lib/views/community/region_map_explore_sheet.dart',
    ).readAsStringSync();
    expect(sheet.contains('RegionShopListCopy'), isFalse);
    expect(sheet.contains('반경 넓히기'), isFalse);
  });
}
