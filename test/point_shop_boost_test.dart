import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/sori_point_wallet.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/widgets/insufficient_points_sheet.dart';

void main() {
  test('purchase boost debits Echo only and never settlement', () async {
    final repo = MemorySoriRepository();
    const shopId = 'shop-boost';

    await repo.purchaseSoriPoints(shopId: shopId, amount: 120);
    await repo.creditSettlementForTest(shopId: shopId, amount: 20000);

    final before = await repo.loadPointWallet(shopId);
    expect(before.settlementBalance, 20000);

    final result = await repo.purchasePointShopItem(
      shopId: shopId,
      sku: 'boost_bump_4h',
      targetType: 'chart',
      targetId: 'chart-1',
    );

    expect(result.ok, isTrue);
    expect(result.pointsSpent, 5);
    expect(result.settlementBalance, 20000);
    expect(result.placement?.chartId, 'chart-1');

    final after = await repo.loadPointWallet(shopId);
    expect(after.pointTotal, before.pointTotal - 5);
    expect(after.settlementBalance, 20000);
  });

  test('insufficient boost returns gap without throwing', () async {
    final repo = MemorySoriRepository();
    const shopId = 'shop-poor';

    // default free 20E — need 59E for 7d spotlight
    final result = await repo.purchasePointShopItem(
      shopId: shopId,
      sku: 'boost_spotlight_7d',
      targetType: 'chart',
      targetId: 'chart-x',
    );

    expect(result.ok, isFalse);
    expect(result.insufficient, isTrue);
    expect(result.need, 59);
    expect(result.have, lessThan(59));
  });

  test('PointPack recommend covers boost gap (55E pack)', () {
    expect(PointPack.catalog.first.echo, 55);
    expect(PointPack.catalog.first.sku, 'sori_e_55');
  });

  test('interleavedCaseFeed mixes boost without pin-all', () async {
    MemorySoriRepository.resetFanBoostStateForTest();
    final repo = MemorySoriRepository();
    final store = SoriStore(repository: repo);
    await store.refreshCommunityHotCases();

    if (store.communityHotCases.isEmpty) {
      expect(store.interleavedCaseFeed(), isA<List>());
      return;
    }

    final target = store.communityHotCases.first.chart.id;
    final shopId = store.communityHotCases.first.shop.id;
    await repo.purchaseSoriPoints(shopId: shopId, amount: 55);
    final bought = await repo.purchasePointShopItem(
      shopId: shopId,
      sku: 'boost_bump_4h',
      targetType: 'chart',
      targetId: target,
    );
    expect(bought.ok, isTrue);

    await store.refreshCommunityHotCases();
    final local = store.interleavedCaseFeed(viewerId: 't1');
    expect(local, isNotEmpty);
    expect(local.any((e) => e.chart.id == target && e.isBoosted), isTrue);
    // pin-all 폐기: 전 항목 부스트면 실패. 선두 연속 길이는 시드/점수에 따라 1~N.
    expect(local.every((e) => e.isBoosted), isFalse);
  });

  testWidgets('insufficient Echo sheet offers one-tap charge CTA',
      (tester) async {
    final store = SoriStore(repository: MemorySoriRepository());

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showInsufficientPointsSheet(
                      context,
                      store: store,
                      need: 89,
                      have: 20,
                      productLabel: '부스터',
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Echo가 부족해요'), findsOneWidget);
    expect(find.textContaining('1 Echo = 100원'), findsOneWidget);
    expect(find.textContaining('충전하고 계속'), findsOneWidget);
  });
}
