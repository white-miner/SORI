import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/fan_supporter.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/widgets/fan_sponsor_credits.dart';

void main() {
  test('multi Fan-Boost aggregates by wallet Echo DESC', () async {
    MemorySoriRepository.resetFanBoostStateForTest();
    final repo = MemorySoriRepository();
    final store = SoriStore(repository: repo);
    await store.refreshCommunityHotCases();
    expect(store.communityHotCases, isNotEmpty);
    final chartId = store.communityHotCases.first.chart.id;
    final shopId = store.communityHotCases.first.shop.id;

    await repo.purchaseCustomerEcho(customerId: 'cust-a', amount: 600);
    await repo.purchaseCustomerEcho(customerId: 'cust-b', amount: 200);
    await repo.purchaseCustomerEcho(customerId: 'cust-c', amount: 200);
    await repo.purchaseCustomerEcho(customerId: 'cust-d', amount: 200);

    final a1 = await repo.purchaseFanBoost(
      customerId: 'cust-a',
      sku: 'boost_spotlight_7d',
      targetType: 'chart',
      targetId: chartId,
      targetShopId: shopId,
      fanDisplayName: '민지',
    );
    expect(a1.ok, isTrue);
    await repo.purchaseFanBoost(
      customerId: 'cust-b',
      sku: 'boost_spotlight_12h',
      targetType: 'chart',
      targetId: chartId,
      targetShopId: shopId,
      fanDisplayName: '수연',
    );
    await repo.purchaseFanBoost(
      customerId: 'cust-c',
      sku: 'boost_bump_4h',
      targetType: 'chart',
      targetId: chartId,
      targetShopId: shopId,
      fanDisplayName: '하나',
    );
    await repo.purchaseFanBoost(
      customerId: 'cust-d',
      sku: 'boost_bump_4h',
      targetType: 'chart',
      targetId: chartId,
      targetShopId: shopId,
      fanDisplayName: '지아',
    );
    await repo.purchaseFanBoost(
      customerId: 'cust-a',
      sku: 'boost_bump_4h',
      targetType: 'chart',
      targetId: chartId,
      targetShopId: shopId,
      fanDisplayName: '민지',
    );

    final ranked = await repo.loadFanBoostSupporters(targetId: chartId);
    expect(ranked.length, 4);
    expect(ranked.first.name, '민지');
    expect(ranked.first.echoSpent, 59 + 5); // 7d + bump
    expect(ranked[1].name, '수연');
    expect(ranked[1].echoSpent, 9);

    await store.refreshCommunityHotCases();
    final item =
        store.communityHotCases.firstWhere((e) => e.chart.id == chartId);
    expect(item.isFanBoosted, isTrue);
    expect(item.effectiveFanSupporters.length, 4);
    expect(item.effectiveFanSupporters.first.name, '민지');
  });

  testWidgets('FanBoostCreditStrip stays below media slot (max 44px)',
      (tester) async {
    final supporters = FanSupporterEntry.ranked([
      const FanSupporterEntry(name: '민지', echoSpent: 178),
      const FanSupporterEntry(name: '수연', echoSpent: 89),
      const FanSupporterEntry(name: '하나', echoSpent: 29),
      const FanSupporterEntry(name: '지아', echoSpent: 29),
      const FanSupporterEntry(name: '유나', echoSpent: 29),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(
                key: Key('ba-media'),
                height: 200,
                child: ColoredBox(color: Colors.grey),
              ),
              FanBoostCreditStrip(supporters: supporters),
              const SizedBox(key: Key('action-bar'), height: 40),
            ],
          ),
        ),
      ),
    );

    expect(find.textContaining('민지님 외 4명이 후원'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget); // 5 total → top3 +2

    final strip = tester.getSize(find.byType(FanBoostCreditStrip));
    expect(strip.height, lessThanOrEqualTo(52)); // padding + ≤44 content

    final mediaBottom = tester.getBottomLeft(find.byKey(const Key('ba-media'))).dy;
    final stripTop = tester.getTopLeft(find.byType(FanBoostCreditStrip)).dy;
    expect(stripTop, greaterThanOrEqualTo(mediaBottom));
  });
}
