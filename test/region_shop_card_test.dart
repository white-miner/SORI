import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/services/shop_market_service.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/theme/sori_tokens.dart';
import 'package:sori/utils/area_search_center.dart';
import 'package:sori/utils/region_shop_list_copy.dart';
import 'package:sori/views/community/region_nearby_map_section.dart';

const _centerLat = 35.8562;
const _centerLng = 129.2247;
final _captureKey = GlobalKey();

ShopMarketStoreItem _pieona({String flrNo = '2', String chipKey = 'skin'}) {
  return ShopMarketStoreItem(
    name: '피어나스킨엔바디',
    categoryLabel: '피부 관리실',
    chipKey: chipKey,
    latitude: 35.8571,
    longitude: _centerLng,
    distanceM: 100,
    address: '경북 경주시 원화로 234',
    lotAddress: '황오동 115-18',
    bizesId: 'MA0101',
    indsLclsNm: '수리·개인',
    indsMclsNm: '이용·미용',
    indsSclsNm: '피부 관리실',
    adongNm: '황오동',
    flrNo: flrNo,
  );
}

ShopMarketInsight _insight(List<ShopMarketStoreItem> items) {
  return ShopMarketInsight(
    ok: true,
    locationLabel: '경주시 황오동',
    radiusM: 1000,
    category: '전체',
    statsYm: '202609',
    fetchedAt: DateTime.utc(2026, 9, 25),
    sources: const [],
    storesOk: true,
    totalInRadius: items.length,
    sameCategoryCount: items.length,
    sampleNames: const [],
    storeItems: items,
    storesError: null,
    storesComplete: true,
    storesSource: '소상공인시장진흥공단 상가(상권)정보',
    storesRetrievedAt: '2026-09-25T17:54:00Z',
    populationOk: false,
    admCd: null,
    dongName: null,
    popTotal: 0,
    popMale: 0,
    popFemale: 0,
    ages: const [],
    populationError: null,
    storesPer1kPop: null,
    centerLatitude: _centerLat,
    centerLongitude: _centerLng,
  );
}

class _Harness {
  int licenseCalls = 0;
  int positionCalls = 0;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  required List<ShopMarketStoreItem> items,
  ({double lat, double lng})? position,
  ShopLicenseStatus license = ShopLicenseStatus.unmatched,
  Size size = const Size(390, 900),
  Future<ShopLicenseStatus> Function(ShopMarketStoreItem)? licenseLoader,
}) async {
  final harness = _Harness();
  // Fresh state per pump (license/position caches live in the section state).
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final store = SoriStore();
  store.shop = store.shop.copyWith(
    latitude: _centerLat,
    longitude: _centerLng,
    address: '경주시 황오동',
  );
  await tester.pumpWidget(
    RepaintBoundary(key: _captureKey, child: MaterialApp(
      theme: ThemeData(fontFamily: 'RegionPreview', scaffoldBackgroundColor: SoriTokens.canvas),
      home: Scaffold(
        body: ListView(
          children: [
            RegionNearbyMapSection(
              store: store,
              radiusKm: 1,
              nearbyLoader: ({
                required double latitude,
                required double longitude,
                required int radiusM,
                bool force = false,
              }) async => _insight(items),
              devicePositionLoader: () async {
                harness.positionCalls++;
                return position;
              },
              licenseLoader: (item) async {
                harness.licenseCalls++;
                return licenseLoader == null ? license : await licenseLoader(item);
              },
            ),
          ],
        ),
      ),
    )),
  );
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return harness;
}

Future<void> _selectFirstRow(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const Key('region-shop-list-count')),
    const Offset(0, -520),
  );
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.ensureVisible(find.byKey(const Key('region-market-store-0')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('region-market-store-0')));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Color? _textColor(WidgetTester tester, Finder chip) {
  final rich = tester.widget<RichText>(
    find.descendant(of: chip, matching: find.byType(RichText)).first,
  );
  return rich.text.style?.color;
}

Color? _chipFill(WidgetTester tester, Finder chip) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(of: chip, matching: find.byType(DecoratedBox)).first,
  );
  return (box.decoration as BoxDecoration).color;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a transient license failure retries on the next selection', (tester) async {
    var attempts = 0;
    final h = await _pump(tester, items: [_pieona()], licenseLoader: (_) async {
      attempts++;
      if (attempts == 1) throw StateError('temporary failure');
      return ShopLicenseStatus(matched: true, status: 'open', licensedOn: DateTime(2019));
    });
    await _selectFirstRow(tester);
    expect(find.byKey(const Key('region-selected-chip-open')), findsNothing);
    await _selectFirstRow(tester);
    expect(h.licenseCalls, 2);
    expect(find.byKey(const Key('region-selected-chip-open')), findsOneWidget);
    await _selectFirstRow(tester);
    expect(h.licenseCalls, 2, reason: 'successful lookups are cached');
  });

  for (final width in [360.0, 1024.0]) {
    testWidgets('card preview at ${width.toInt()}px', (tester) async {
      final fontPath = Platform.environment['REGION_PREVIEW_FONT'];
      if (fontPath != null) {
        await tester.runAsync(() async {
          final loader = FontLoader('RegionPreview');
          loader.addFont(Future.value(ByteData.sublistView(await File(fontPath).readAsBytes())));
          await loader.load();
        });
      }
      await _pump(tester, items: [_pieona()], size: Size(width, 1100),
        position: (lat: 35.8553, lng: _centerLng),
        license: ShopLicenseStatus(matched: true, status: 'open', licensedOn: DateTime(2019, 5, 10)));
      await _selectFirstRow(tester);
      await tester.ensureVisible(find.byKey(const Key('region-selected-address')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      if (Platform.environment['REGION_CAPTURE'] == '1') {
        await tester.runAsync(() async {
          final boundary = _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('build/region-previews')..createSync(recursive: true);
          await File('${dir.path}/region-${width.toInt()}.png').writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }

  group('ShopMarketStoreItem floor / address / plain category', () {
    test('floorLabel reads public flrNo without guessing', () {
      String? floor(String raw) => _pieona(flrNo: raw).floorLabel;
      expect(floor('2'), '2층');
      expect(floor('1'), '1층');
      expect(floor('2층'), '2층');
      expect(floor('3F'), '3층');
      expect(floor('B1'), '지하 1층');
      expect(floor('b2'), '지하 2층');
      expect(floor('지하1'), '지하 1층');
      expect(floor('지1'), '지하 1층');
      expect(floor('지'), '지하');
      expect(floor('지하'), '지하');
      expect(floor(''), isNull);
      expect(floor('   '), isNull);
      expect(floor('0'), isNull);
      expect(floor('옥탑'), isNull);
      expect(floor('1~2'), isNull);
    });

    test('addressWithFloor adds the floor to the road address only when known', () {
      expect(_pieona().addressWithFloor, '경북 경주시 원화로 234, 2층');
      expect(_pieona(flrNo: 'B1').addressWithFloor, '경북 경주시 원화로 234, 지하 1층');
      expect(_pieona(flrNo: '').addressWithFloor, '경북 경주시 원화로 234');
      expect(_pieona(flrNo: '??').addressWithFloor, '경북 경주시 원화로 234');
      const lotOnly = ShopMarketStoreItem(
        name: '지번샵', categoryLabel: '', chipKey: 'nail', latitude: 0,
        longitude: 0, distanceM: 0, address: '', lotAddress: '황오동 1',
        sourceAddr: '옛주소',
      );
      expect(lotOnly.addressWithFloor, '황오동 1');
      const none = ShopMarketStoreItem(
        name: '빈샵', categoryLabel: '', chipKey: 'nail', latitude: 0,
        longitude: 0, distanceM: 0, address: '', sourceAddr: '옛주소',
      );
      expect(none.addressWithFloor, isEmpty);
    });

    test('plainCategoryLabel is one friendly word, never the 중/대분류', () {
      expect(_pieona().plainCategoryLabel, '피부관리');
      String? label(String chip, [String scls = '']) => ShopMarketStoreItem(
            name: 'x', categoryLabel: scls, chipKey: chip, latitude: 0,
            longitude: 0, distanceM: 0, address: '', indsSclsNm: scls,
            indsMclsNm: '이용·미용', indsLclsNm: '수리·개인',
          ).plainCategoryLabel;
      expect(label('nail', '네일숍'), '네일');
      expect(label('hair', '미용실'), '헤어');
      expect(label('barber', '이용원'), '바버');
      expect(label('tattoo'), '타투');
      expect(label('makeup'), '메이크업');
      expect(label('semi_permanent'), '반영구');
      expect(label('skin', '속눈썹 연장'), '속눈썹');
      expect(label('skin', '왁싱 전문'), '왁싱');
      expect(label('other', '기타 미용업'), isNull);
    });

    test('fromMap parses flr_no/bld_nm/ksic_nm and legacy rows still work', () {
      final item = ShopMarketStoreItem.fromMap({
        'name': '피어나스킨엔바디',
        'chip_key': 'skin',
        'address': '경북 경주시 원화로 234',
        'flr_no': '2',
        'bld_nm': '황오빌딩',
        'ksic_nm': '피부 미용업',
        'bld_mng_no': '4713011200101150018000001',
        'brch_nm': '',
      });
      expect(item.flrNo, '2');
      expect(item.bldNm, '황오빌딩');
      expect(item.ksicNm, '피부 미용업');
      expect(item.bldMngNo, '4713011200101150018000001');
      expect(item.brchNm, isEmpty);
      expect(item.addressWithFloor, '경북 경주시 원화로 234, 2층');
      final copied = item.copyWith(distanceM: 9);
      expect(copied.flrNo, '2');
      expect(copied.ksicNm, '피부 미용업');

      final legacy = ShopMarketStoreItem.fromMap({'name': '옛샵', 'address': '테헤란로 1'});
      expect(legacy.flrNo, isEmpty);
      expect(legacy.floorLabel, isNull);
      expect(legacy.addressWithFloor, '테헤란로 1');
    });
  });

  group('ShopLicenseStatus', () {
    test('fromMap keeps matched fields and unmatched never claims closure', () {
      final open = ShopLicenseStatus.fromMap({
        'matched': true,
        'status': 'open',
        'status_label': '영업/정상',
        'licensed_on': '2019-05-10',
        'closed_on': null,
        'source': '행정안전부 생활_미용업 인허가 정보',
        'fetched_at': '2026-09-25T17:54:00Z',
      });
      expect(open.isOpen, isTrue);
      expect(open.licensedOn, DateTime(2019, 5, 10));
      expect(open.yearsInBusiness(DateTime(2026, 9, 26)), 8);

      final unmatched = ShopLicenseStatus.fromMap({
        'matched': false,
        'status': null,
        'reason': 'no_match',
      });
      expect(unmatched.matched, isFalse);
      expect(unmatched.isOpen, isFalse);
      expect(unmatched.status, isNull);
      expect(unmatched.yearsInBusiness(DateTime(2026, 9, 26)), isNull);
    });

    test('N년째 = (올해 − 인허가 연도) + 1', () {
      ShopLicenseStatus since(DateTime d) =>
          ShopLicenseStatus(matched: true, status: 'open', licensedOn: d);
      final now = DateTime(2026, 9, 26);
      expect(since(DateTime(2019, 1, 1)).yearsInBusiness(now), 8);
      expect(since(DateTime(2025, 9, 26)).yearsInBusiness(now), 2);
      expect(since(DateTime(2025, 12, 1)).yearsInBusiness(now), 2);
      expect(since(DateTime(2026, 3, 1)).yearsInBusiness(now), 1);
      expect(since(DateTime(2026, 10, 1)).yearsInBusiness(now), isNull);
    });
  });

  testWidgets('selected card: floor address, pink 업종 chip, no 분류/미제공/내 샵 text', (
    tester,
  ) async {
    final h = await _pump(tester, items: [_pieona()]);
    expect(h.licenseCalls, 0, reason: 'no license lookups for list rows');
    await _selectFirstRow(tester);

    expect(find.byTooltip('선택 닫기'), findsOneWidget);
    expect(find.text('경북 경주시 원화로 234, 2층 · 황오동'), findsWidgets);
    final industry = find.byKey(const Key('region-selected-chip-industry'));
    expect(industry, findsOneWidget);
    expect(find.descendant(of: industry, matching: find.text('피부관리')), findsOneWidget);
    expect(_textColor(tester, industry), SoriTokens.shopChipIndustryText);
    expect(_chipFill(tester, industry), SoriTokens.shopChipIndustryBg);

    final footer = tester.widget<Text>(find.byKey(const Key('region-selected-footer')));
    expect(footer.data, startsWith('지번 황오동 115-18 · 출처 소상공인시장진흥공단 상가(상권)정보 · 조회 '));
    expect(footer.data, matches(RegExp(r'조회 \d{2}\.\d{2}\.\d{2} \d{2}:\d{2}$')));

    expect(find.textContaining('이용·미용'), findsNothing);
    expect(find.textContaining('수리·개인'), findsNothing);
    expect(find.textContaining('현재 제공되지 않음'), findsNothing);
    expect(find.textContaining('내 샵'), findsNothing);
    expect(h.licenseCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('distance chip hides without GPS and never shows 현재 제공되지 않음', (
    tester,
  ) async {
    final h = await _pump(tester, items: [_pieona()]);
    await _selectFirstRow(tester);
    expect(h.positionCalls, 1);
    expect(find.byKey(const Key('region-selected-chip-distance')), findsNothing);
    expect(find.byKey(const Key('region-market-chip-distance-0')), findsNothing);
    expect(find.textContaining('현재 제공되지 않음'), findsNothing);

    expect(find.byKey(const Key('region-selected-chip-industry')), findsOneWidget);
  });

  testWidgets('distance chip uses the injected device position, not the search center', (
    tester,
  ) async {
    const device = (lat: 35.8553, lng: _centerLng);
    final shop = _pieona();
    final expected = RegionShopListCopy.distanceLabel(AreaSearchCenter.distanceMeters(
      centerLat: device.lat,
      centerLng: device.lng,
      pointLat: shop.latitude,
      pointLng: shop.longitude,
    )!)!;
    await _pump(tester, items: [shop], position: device);
    await _selectFirstRow(tester);

    final chip = find.byKey(const Key('region-selected-chip-distance'));
    expect(chip, findsOneWidget);
    expect(find.descendant(of: chip, matching: find.text(expected)), findsOneWidget);
    expect(expected, '200m');
    expect(find.byKey(const Key('region-market-chip-distance-0')), findsOneWidget);
  });

  testWidgets('matched open license shows blue 정상 영업 and green N년째 영업', (
    tester,
  ) async {
    final license = ShopLicenseStatus(
      matched: true,
      status: 'open',
      statusLabel: '영업/정상',
      licensedOn: DateTime(2019, 5, 10),
    );
    await _pump(tester, items: [_pieona()], license: license);
    await _selectFirstRow(tester);

    final open = find.byKey(const Key('region-selected-chip-open'));
    final years = find.byKey(const Key('region-selected-chip-years'));
    expect(open, findsOneWidget);
    expect(years, findsOneWidget);
    expect(find.descendant(of: open, matching: find.text('정상 영업')), findsOneWidget);
    final n = license.yearsInBusiness(DateTime.now())!;
    expect(find.descendant(of: years, matching: find.text('$n년째 영업')), findsOneWidget);
    expect(_textColor(tester, open), SoriTokens.shopChipOpenText);
    expect(_chipFill(tester, open), SoriTokens.shopChipOpenBg);
    expect(_textColor(tester, years), SoriTokens.shopChipYearsText);
    expect(_chipFill(tester, years), SoriTokens.shopChipYearsBg);
  });

  testWidgets('unmatched, closed, and suspended licenses show no status chips', (
    tester,
  ) async {
    for (final license in [
      ShopLicenseStatus.unmatched,
      ShopLicenseStatus(matched: true, status: 'closed', licensedOn: DateTime(2019)),
      ShopLicenseStatus(matched: true, status: 'suspended', licensedOn: DateTime(2019)),
    ]) {
      await _pump(tester, items: [_pieona()], license: license);
      await _selectFirstRow(tester);
      expect(find.byKey(const Key('region-selected-chip-open')), findsNothing);
      expect(find.byKey(const Key('region-selected-chip-years')), findsNothing);
      expect(find.textContaining('폐업'), findsNothing);
      expect(find.textContaining('휴업'), findsNothing);
      expect(find.byKey(const Key('region-selected-chip-industry')), findsOneWidget);
    }
  });

  testWidgets('Naver buttons are brand green with white text on card and rows', (
    tester,
  ) async {
    await _pump(tester, items: [_pieona()]);
    await _selectFirstRow(tester);
    for (final key in const [
      Key('region-selected-map-cta'),
      Key('region-market-map-cta-0'),
    ]) {
      final finder = find.byKey(key);
      expect(finder, findsOneWidget);
      final button = tester.widget<OutlinedButton>(finder);
      expect(button.style!.backgroundColor!.resolve(<WidgetState>{}), const Color(0xFF03C75A));
      expect(button.style!.foregroundColor!.resolve(<WidgetState>{}), Colors.white);
      expect(find.descendant(of: finder, matching: find.text('네이버에서 샵 찾기')), findsOneWidget);
      expect(_textColor(tester, finder), Colors.white);
    }
  });
}
