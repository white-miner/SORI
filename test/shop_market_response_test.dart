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
}
