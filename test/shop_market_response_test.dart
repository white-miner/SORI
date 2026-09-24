import 'package:flutter_test/flutter_test.dart';
import 'package:sori/services/shop_market_service.dart';

void main() {
  test('legacy and partial responses never assert complete coverage', () {
    for (final complete in [null, false]) {
      final result = ShopMarketInsight.fromMap({
        'stores': {'ok': true, if (complete != null) 'complete': complete, 'items': []},
      });
      expect(result.storesOk, isTrue);
      expect(result.storesComplete, isFalse);
    }
  });

  test('successful empty result remains a complete zero', () {
    final result = ShopMarketInsight.fromMap({
      'latitude': 37.5, 'longitude': 127.0,
      'stores': {'ok': true, 'complete': true, 'items': [], 'total_in_radius': 0},
    });
    expect(result.storesComplete, isTrue);
    expect(result.storeItems, isEmpty);
    expect(result.centerLatitude, 37.5);
  });

  test('API failure retains its reason without making a success claim', () {
    final result = ShopMarketInsight.fromMap({
      'stores': {'ok': false, 'complete': false, 'error': 'api_30', 'items': []},
    });
    expect(result.storesOk, isFalse);
    expect(result.storesComplete, isFalse);
    expect(result.storesError, 'api_30');
  });

  test('store metadata is kept and missing keys stay empty', () {
    final result = ShopMarketInsight.fromMap({
      'stats_ym': '202609',
      'stores': {
        'ok': true,
        'complete': true,
        'source': '소상공인시장진흥공단 상가(상권)정보',
        'retrieved_at': '2026-09-24T00:41:00Z',
        'items': [
          {
            'name': '소리샵',
            'category_label': '피부미용업',
            'chip_key': 'skin',
            'lat': 37.5,
            'lng': 127.0,
            'distance_m': 12,
            'address': '서울특별시 강남구 테헤란로 1',
            'lot_address': '서울특별시 강남구 역삼동 1',
            'bizes_id': 'shop-1',
            'inds_lcls_cd': 'L1',
            'inds_lcls_nm': '수리·개인서비스',
            'inds_mcls_cd': 'M1',
            'inds_mcls_nm': '미용',
            'inds_scls_cd': 'S1',
            'inds_scls_nm': '피부미용업',
            'ctprvn_cd': '11',
            'ctprvn_nm': '서울특별시',
            'signgu_cd': '11680',
            'signgu_nm': '강남구',
            'adong_cd': '11680640',
            'adong_nm': '역삼1동',
          },
        ],
      },
      'population': {
        'ok': false,
        'total': 0,
        'error': 'missing_MOIS_POP_SERVICE_KEY',
      },
    });

    expect(result.statsYm, '202609');
    expect(result.storesSource, '소상공인시장진흥공단 상가(상권)정보');
    expect(result.storesRetrievedAt, '2026-09-24T00:41:00Z');
    expect(result.sourceText, '소상공인시장진흥공단 상가(상권)정보');
    expect(
      result.queryTimeText,
      ShopMarketInsight.formatQueryTime('2026-09-24T00:41:00Z'),
    );
    expect(result.queryTimeText, isNot(ShopMarketInsight.fieldUnavailable));
    expect(result.populationError, 'missing_MOIS_POP_SERVICE_KEY');
    expect(result.popTotal, 0);
    expect(result.sourceText, isNot(result.populationError));

    final item = result.storeItems.single;
    expect(item.address, '서울특별시 강남구 테헤란로 1');
    expect(item.lotAddress, '서울특별시 강남구 역삼동 1');
    expect(item.address, isNot(item.lotAddress));
    expect(item.bizesId, 'shop-1');
    expect(item.indsLclsCd, 'L1');
    expect(item.indsLclsNm, '수리·개인서비스');
    expect(item.indsMclsCd, 'M1');
    expect(item.indsMclsNm, '미용');
    expect(item.indsSclsCd, 'S1');
    expect(item.indsSclsNm, '피부미용업');
    expect(item.ctprvnNm, '서울특별시');
    expect(item.signguNm, '강남구');
    expect(item.adongNm, '역삼1동');
    expect(item.industryDisplay, '피부미용업 · 미용 · 수리·개인서비스');
    expect(item.industryDisplay.contains('L1'), isFalse);
    expect(item.industryDisplay.contains('S1'), isFalse);

    final copied = item.copyWith(distanceM: 30);
    expect(copied.distanceM, 30);
    expect(copied.bizesId, 'shop-1');
    expect(copied.lotAddress, item.lotAddress);
    expect(copied.adongNm, '역삼1동');
  });

  test('absent public fields stay blank and do not borrow the lot address', () {
    final item = ShopMarketStoreItem.fromMap({
      'name': '이름만',
      'lot_address': '지번만 있음',
    });
    expect(item.address, isEmpty);
    expect(item.lotAddress, '지번만 있음');
    expect(item.bizesId, isEmpty);
    expect(item.indsLclsCd, isEmpty);
    expect(item.indsLclsNm, isEmpty);
    expect(item.indsMclsCd, isEmpty);
    expect(item.indsMclsNm, isEmpty);
    expect(item.indsSclsCd, isEmpty);
    expect(item.indsSclsNm, isEmpty);
    expect(item.ctprvnCd, isEmpty);
    expect(item.ctprvnNm, isEmpty);
    expect(item.signguCd, isEmpty);
    expect(item.signguNm, isEmpty);
    expect(item.adongCd, isEmpty);
    expect(item.adongNm, isEmpty);
    expect(item.industryDisplay, isEmpty);
    expect(item.sourceAddr, isEmpty);
    expect(item.searchPlace, '지번만 있음');
  });

  test('search place falls back without copying addr into the road field', () {
    final road = ShopMarketStoreItem.fromMap({
      'name': '도로샵',
      'address': '테헤란로 1',
      'lot_address': '역삼동 1',
      'addr': '옛주소',
    });
    expect(road.address, '테헤란로 1');
    expect(road.searchPlace, '테헤란로 1');

    final lot = ShopMarketStoreItem.fromMap({
      'name': '지번샵',
      'lot_address': '역삼동 1',
      'addr': '옛주소',
    });
    expect(lot.address, isEmpty);
    expect(lot.searchPlace, '역삼동 1');

    final legacy = ShopMarketStoreItem.fromMap({
      'name': '옛샵',
      'addr': '옛골목 9',
    });
    expect(legacy.address, isEmpty);
    expect(legacy.lotAddress, isEmpty);
    expect(legacy.sourceAddr, '옛골목 9');
    expect(legacy.searchPlace, '옛골목 9');

    final nameOnly = ShopMarketStoreItem.fromMap({'name': '이름만'});
    expect(nameOnly.searchPlace, isEmpty);
  });

  test('unreadable retrieved_at stays unavailable and stats_ym is not the query time', () {
    for (final raw in ['', '   ', '어제', '2026-13-99', '2026-02-31', 'not-a-date']) {
      expect(
        ShopMarketInsight.formatQueryTime(raw),
        ShopMarketInsight.fieldUnavailable,
      );
    }

    final result = ShopMarketInsight.fromMap({
      'stats_ym': '202609',
      'stores': {
        'ok': true,
        'retrieved_at': 'not-a-date',
        'items': [],
      },
      'population': {'ok': false, 'total': 0, 'error': 'missing_MOIS_POP_SERVICE_KEY'},
    });
    expect(result.statsYm, '202609');
    expect(result.storesRetrievedAt, 'not-a-date');
    expect(result.queryTimeText, '현재 제공되지 않음');
    expect(result.storesSource, isEmpty);
    expect(result.sourceText, '현재 제공되지 않음');
    expect(result.queryTimeText, isNot(result.statsYm));
    expect(result.sourceText, isNot(result.populationError));
  });
}
