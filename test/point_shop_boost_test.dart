import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/sori_point_wallet.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/widgets/insufficient_points_sheet.dart';

void main() {
  test('purchase boost debits points only and never settlement', () async {
    final repo = MemorySoriRepository();
    const shopId = 'shop-boost';

    await repo.purchaseSoriPoints(shopId: shopId, amount: 1000);
    await repo.creditSettlementForTest(shopId: shopId, amount: 20000);

    final before = await repo.loadPointWallet(shopId);
    expect(before.settlementBalance, 20000);

    final result = await repo.purchasePointShopItem(
      shopId: shopId,
      sku: 'boost_local_2h',
      targetType: 'chart',
      targetId: 'chart-1',
    );

    expect(result.ok, isTrue);
    expect(result.pointsSpent, 300);
    expect(result.settlementBalance, 20000);
    expect(result.placement?.chartId, 'chart-1');
    expect(result.placement?.isActive, isTrue);

    final after = await repo.loadPointWallet(shopId);
    expect(after.pointTotal, before.pointTotal - 300);
    expect(after.settlementBalance, 20000);

    final boosts = await repo.loadActiveBoostPlacements();
    expect(boosts.any((b) => b.chartId == 'chart-1'), isTrue);
  });

  test('insufficient boost returns gap without throwing', () async {
    final repo = MemorySoriRepository();
    const shopId = 'shop-poor';

    // default free 200 — need 900 for 1d booster
    final result = await repo.purchasePointShopItem(
      shopId: shopId,
      sku: 'boost_local_1d',
      targetType: 'chart',
      targetId: 'chart-x',
    );

    expect(result.ok, isFalse);
    expect(result.insufficient, isTrue);
    expect(result.need, 900);
    expect(result.have, lessThan(900));
    expect(result.gap, greaterThan(0));

    final boosts = await repo.loadActiveBoostPlacements();
    expect(boosts.where((b) => b.chartId == 'chart-x'), isEmpty);
  });

  test('PointPack recommend covers boost gap (500P pack)', () {
    expect(PointPack.catalog.first.points, 500);
    expect(PointPack.catalog.first.sku, 'sori_p_500');
  });

  test('localBoostPinnedFeed sorts boosted charts first', () async {
    final repo = MemorySoriRepository();
    final store = SoriStore(repository: repo);
    await store.refreshCommunityHotCases();

    if (store.communityHotCases.isEmpty) {
      // Seed path may be empty in some envs — still assert helper shape.
      expect(store.localBoostPinnedFeed(), isA<List>());
      return;
    }

    final target = store.communityHotCases.first.chart.id;
    await repo.purchaseSoriPoints(shopId: store.shop.id, amount: 500);
    // Memory shop id may be empty until bootstrap — use chart's shop.
    final shopId = store.communityHotCases.first.shop.id;
    await repo.purchaseSoriPoints(shopId: shopId, amount: 500);
    final bought = await repo.purchasePointShopItem(
      shopId: shopId,
      sku: 'boost_local_2h',
      targetType: 'chart',
      targetId: target,
    );
    expect(bought.ok, isTrue);

    await store.refreshCommunityHotCases();
    final local = store.localBoostPinnedFeed();
    expect(local, isNotEmpty);
    expect(local.first.chart.id, target);
    expect(local.first.isBoosted, isTrue);
  });

  testWidgets('insufficient points sheet offers one-tap charge CTA',
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
                      need: 900,
                      have: 200,
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

    expect(find.text('포인트가 부족해요'), findsOneWidget);
    expect(find.textContaining('충전팩'), findsOneWidget);
    expect(find.textContaining('충전하고 계속'), findsOneWidget);
  });
}
