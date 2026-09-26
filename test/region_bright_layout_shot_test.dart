import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/services/shop_market_service.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/utils/our_area_category.dart';
import 'package:sori/views/community/region_nearby_map_section.dart';
import 'package:sori/widgets/floating_pill_nav.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('phone layout keeps chips, search, sheet, and nav apart', (tester) async {
    final semantics = tester.ensureSemantics();
    const centerLat = 35.856;
    const centerLng = 129.224;
    ShopMarketStoreItem shop({
      required String name,
      required String chipKey,
      required double lat,
      required String address,
      String categoryLabel = '피부미용업',
    }) {
      return ShopMarketStoreItem(
        name: name,
        categoryLabel: categoryLabel,
        chipKey: chipKey,
        latitude: lat,
        longitude: centerLng,
        distanceM: 180,
        address: address,
        lotAddress: '황오동 1',
        adongNm: '황오동',
        indsSclsNm: categoryLabel,
      );
    }

    final data = ShopMarketInsight(
      ok: true,
      locationLabel: '경주시 황오동',
      radiusM: 1000,
      category: '전체',
      statsYm: '202609',
      fetchedAt: DateTime.utc(2026, 9, 24),
      sources: const [],
      storesOk: true,
      totalInRadius: 3,
      sameCategoryCount: 3,
      sampleNames: const [],
      storeItems: [
        shop(name: '밝은피부', chipKey: OurAreaCategory.skin, lat: 35.8572, address: '경북 경주시 화랑로 65'),
        shop(name: '밝은네일', chipKey: OurAreaCategory.nail, lat: 35.8554, address: '경상북도 경주시', categoryLabel: '네일샵'),
        shop(name: '밝은헤어', chipKey: OurAreaCategory.hair, lat: 35.8546, address: '경상북도 경주시 황오동', categoryLabel: '두발미용업'),
      ],
      storesError: null,
      storesComplete: true,
      storesSource: '소상공인시장진흥공단 상가(상권)정보',
      storesRetrievedAt: '2026-09-24T02:00:00Z',
      populationOk: false,
      admCd: null,
      dongName: null,
      popTotal: 0,
      popMale: 0,
      popFemale: 0,
      ages: const [],
      populationError: null,
      storesPer1kPop: null,
      centerLatitude: centerLat,
      centerLongitude: centerLng,
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = SoriStore();
    store.shop = store.shop.copyWith(
      latitude: centerLat,
      longitude: centerLng,
      address: '경주시 황오동',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          extendBody: true,
          body: Semantics(
            label: '우리지역. 가까운 뷰티샵을 찾고, 나에게 맞는 곳을 만나세요.',
            container: true,
            explicitChildNodes: true,
            child: RegionNearbyMapSection(
              store: store,
              radiusKm: 1,
              nearbyLoader: ({
                required double latitude,
                required double longitude,
                required int radiusM,
                bool force = false,
              }) async => data,
            ),
          ),
          bottomNavigationBar: FloatingPillNav(
            currentIndex: 3,
            isDirector: true,
            reviewLabel: '리뷰',
            onTap: (_) {},
          ),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final chips = tester.getRect(find.byKey(const Key('region-category-chips')));
    final search = tester.getRect(find.byKey(const Key('region-search-open')));
    final nav = tester.getRect(find.byType(FloatingPillNav));
    final title = tester.getRect(find.text('내 주변 뷰티샵'));
    expect(chips.bottom, lessThan(title.top));
    expect(search.right, lessThanOrEqualTo(390));
    expect(search.top, greaterThanOrEqualTo(0));
    expect(title.bottom, lessThan(nav.top));
    final card = tester.getRect(find.text('밝은피부').first);
    expect(card.bottom, lessThan(nav.top));
    expect(card.top, greaterThan(chips.bottom));

    await tester.tap(find.byKey(const Key('region-shop-category-skin')));
    await tester.pump();
    expect(find.text('밝은네일'), findsNothing);
    expect(find.text('밝은피부'), findsWidgets);

    await tester.drag(find.byKey(const Key('region-shop-list-count')), const Offset(0, -280));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }

    await tester.tap(find.byKey(const Key('region-search-open')));
    await tester.pump();
    expect(find.byKey(const Key('region-shop-search')), findsOneWidget);
    expect(find.text('인기 검색어'), findsOneWidget);
    final field = tester.getRect(find.byKey(const Key('region-shop-search')));
    expect(field.bottom, lessThan(nav.top));

    await tester.tap(find.byKey(const Key('region-popular-피부관리')));
    await tester.pump();
    expect(find.text('피부관리'), findsWidgets);
    await tester.enterText(find.byKey(const Key('region-shop-search')), '밝은피부');
    await tester.pump();
    expect(find.text('밝은피부'), findsWidgets);

    SemanticsNode? fieldNode;
    void walk(SemanticsNode node) {
      final data = node.getSemanticsData();
      if (node.rect.height > 0 && node.rect.height < 120 && data.label.contains('업종')) {
        fieldNode = node;
      }
      node.visitChildren((child) {
        walk(child);
        return true;
      });
    }

    walk(tester.getSemantics(find.byKey(const Key('region-shop-search'))));
    expect(fieldNode, isNotNull);
    expect(fieldNode!.rect.height, lessThan(120));

    await tester.tap(find.byKey(const Key('region-search-hit-밝은피부')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byTooltip('선택 닫기'), findsOneWidget);
    final facts = tester.getRect(find.textContaining('지번 황오동 1'));
    final count = tester.getRect(find.byKey(const Key('region-shop-list-count')));
    expect(
      facts.bottom,
      lessThan(nav.top),
      reason: 'facts=$facts count=$count navTop=${nav.top}',
    );
    expect(facts.top, greaterThan(chips.bottom));
    semantics.dispose();
  });
}
