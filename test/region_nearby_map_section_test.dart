import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/services/shop_market_service.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/utils/our_area_category.dart';
import 'package:sori/views/community/region_nearby_map_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const centerLat = 37.5;
  const centerLng = 127.0;

  ShopMarketStoreItem shop({
    required String name,
    required String chipKey,
    required double lat,
    String categoryLabel = '피부미용업',
    String address = '',
    String lotAddress = '',
    String sourceAddr = '',
    String adongNm = '',
  }) {
    return ShopMarketStoreItem(
      name: name,
      categoryLabel: categoryLabel,
      chipKey: chipKey,
      latitude: lat,
      longitude: centerLng,
      distanceM: 0,
      address: address,
      lotAddress: lotAddress,
      sourceAddr: sourceAddr,
      adongNm: adongNm,
      indsSclsNm: categoryLabel,
    );
  }

  ShopMarketInsight insight({
    required List<ShopMarketStoreItem> items,
    String source = '소상공인시장진흥공단 상가(상권)정보',
    String retrievedAt = '2026-09-24T00:41:00Z',
  }) {
    return ShopMarketInsight(
      ok: true,
      locationLabel: '테스트',
      radiusM: 1000,
      category: '전체',
      statsYm: '202609',
      fetchedAt: DateTime.utc(2026, 9, 24),
      sources: const [],
      storesOk: true,
      totalInRadius: items.length,
      sameCategoryCount: items.length,
      sampleNames: const [],
      storeItems: items,
      storesError: null,
      storesComplete: true,
      storesSource: source,
      storesRetrievedAt: retrievedAt,
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
  }

  Future<void> pumpSection(
    WidgetTester tester, {
    required ShopMarketInsight data,
    double width = 360,
    double radiusKm = 1,
    ValueChanged<double>? onRadiusChanged,
    List<int>? radii,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = SoriStore();
    store.shop = store.shop.copyWith(latitude: centerLat, longitude: centerLng);
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed')) errors.add(details);
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              RegionNearbyMapSection(
                store: store,
                radiusKm: radiusKm,
                onRadiusChanged: onRadiusChanged,
                nearbyLoader: ({
                  required double latitude,
                  required double longitude,
                  required int radiusM,
                  bool force = false,
                }) async {
                  radii?.add(radiusM);
                  return data;
                },
              ),
            ],
          ),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(errors, isEmpty, reason: errors.map((e) => e.exceptionAsString()).join('\n'));
  }

  testWidgets('list and selected cards show lot, dong, source, and query time', (
    tester,
  ) async {
    final data = insight(
      items: [
        shop(
          name: '소리샵',
          chipKey: OurAreaCategory.skin,
          lat: 37.501,
          address: '테헤란로 1',
          lotAddress: '역삼동 1',
          sourceAddr: '옛주소',
          adongNm: '역삼1동',
        ),
      ],
    );
    await pumpSection(tester, data: data);

    expect(find.text('지번\n역삼동 1'), findsOneWidget);
    expect(find.text('행정동\n역삼1동'), findsOneWidget);
    expect(find.text('출처\n소상공인시장진흥공단 상가(상권)정보'), findsWidgets);
    expect(
      find.text('조회 시점\n${ShopMarketInsight.formatQueryTime(data.storesRetrievedAt)}'),
      findsWidgets,
    );
    expect(find.text('도로명\n옛주소'), findsNothing);
    expect(find.text('도로명\n테헤란로 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('region-market-store-0')));
    await tester.pump();

    expect(find.text('지번\n역삼동 1'), findsNWidgets(2));
    expect(find.text('행정동\n역삼1동'), findsNWidgets(2));
    expect(find.text('네이버에서 샵 찾기'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty public fields show 현재 제공되지 않음 at 360px', (tester) async {
    final data = insight(
      source: '',
      retrievedAt: 'not-a-date',
      items: [
        shop(
          name: '빈칸샵',
          chipKey: OurAreaCategory.skin,
          lat: 37.501,
        ),
      ],
    );
    await pumpSection(tester, data: data);

    expect(find.text('지번\n현재 제공되지 않음'), findsOneWidget);
    expect(find.text('행정동\n현재 제공되지 않음'), findsOneWidget);
    expect(find.text('출처\n현재 제공되지 않음'), findsWidgets);
    expect(find.text('조회 시점\n현재 제공되지 않음'), findsWidgets);

    await tester.tap(find.byKey(const Key('region-market-store-0')));
    await tester.pump();

    expect(find.text('지번\n현재 제공되지 않음'), findsNWidgets(2));
    expect(find.text('행정동\n현재 제공되지 않음'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('marker tap, category filter, radius, and naver search stay available', (
    tester,
  ) async {
    final radii = <int>[];
    final data = insight(
      items: [
        shop(
          name: '소리샵',
          chipKey: OurAreaCategory.skin,
          lat: centerLat,
          address: '테헤란로 1',
          lotAddress: '역삼동 1',
          sourceAddr: '옛주소',
          adongNm: '역삼1동',
        ),
        shop(
          name: '헤어샵',
          chipKey: OurAreaCategory.hair,
          lat: 37.502,
          categoryLabel: '두발미용업',
          lotAddress: '헤어지번',
        ),
        shop(
          name: '골목샵',
          chipKey: OurAreaCategory.nail,
          lat: 37.503,
          categoryLabel: '네일샵',
          sourceAddr: '옛골목 9',
        ),
      ],
    );

    double radius = 1;
    final store = _storeAtCenter();
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return ListView(
                children: [
                  RegionNearbyMapSection(
                    store: store,
                    radiusKm: radius,
                    onRadiusChanged: (km) => setState(() => radius = km),
                    nearbyLoader: ({
                      required double latitude,
                      required double longitude,
                      required int radiusM,
                      bool force = false,
                    }) async {
                      radii.add(radiusM);
                      return data;
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byTooltip('선택 닫기'), findsNothing);
    final map = find.byType(FlutterMap);
    await tester.ensureVisible(map);
    await tester.tap(map);
    await tester.pump();
    expect(find.byTooltip('선택 닫기'), findsOneWidget);
    expect(find.text('지번\n역삼동 1'), findsWidgets);

    await _scrollToTop(tester);
    final hairChip = find.byKey(const Key('region-shop-category-hair'));
    await tester.tap(hairChip);
    await tester.pump();
    expect(find.text('헤어샵'), findsWidgets);
    expect(find.text('소리샵'), findsNothing);
    expect(find.text('골목샵'), findsNothing);

    await _scrollToTop(tester);
    final allChip = find.byKey(const Key('region-shop-category-all'));
    await tester.tap(allChip);
    await tester.pump();
    final search = find.byKey(const Key('region-shop-search'));
    await tester.enterText(search, '옛주소');
    await tester.pump();
    expect(find.text('소리샵'), findsNothing);
    await tester.enterText(find.byKey(const Key('region-shop-search')), '테헤란로');
    await tester.pump();
    expect(find.text('소리샵'), findsWidgets);
    expect(find.text('골목샵'), findsNothing);
    await tester.enterText(find.byKey(const Key('region-shop-search')), '옛골목');
    await tester.pump();
    expect(find.text('골목샵'), findsWidgets);
    expect(find.text('도로명\n옛골목 9'), findsNothing);
    expect(find.text('도로명\n현재 제공되지 않음'), findsOneWidget);

    expect(find.text('네이버에서 샵 찾기'), findsWidgets);
    await _scrollToTop(tester);
    final radiusButton = find.byKey(const Key('region-radius'));
    await tester.ensureVisible(radiusButton);
    await tester.tap(radiusButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('2km').last);
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(radii, contains(1000));
    expect(radii, contains(2000));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _scrollToTop(WidgetTester tester) async {
  for (final state in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
    if (state.position.axis == Axis.vertical) {
      state.position.jumpTo(0);
    }
  }
  await tester.pump();
}

SoriStore _storeAtCenter() {
  final store = SoriStore();
  store.shop = store.shop.copyWith(latitude: 37.5, longitude: 127.0);
  return store;
}
