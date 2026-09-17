import 'package:flutter_test/flutter_test.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/customer_review.dart';
import 'package:sori/services/sori_store.dart';

void main() {
  Future<SoriStore> _boot() async {
    final store = SoriStore(repository: MemorySoriRepository());
    await store.bootstrap();
    return store;
  }

  test('unreplied lane excludes hasDirectorReply', () async {
    final store = await _boot();
    // Seed reviews all have replies — clear one.
    final withReply = store.reviews.firstWhere((r) => r.hasDirectorReply);
    store.reviews[store.reviews.indexWhere((r) => r.id == withReply.id)] =
        withReply.copyWith(clearDirectorReply: true);

    final unreplied =
        store.directorReviewInboxItems(lane: ReviewOpsLane.unreplied);
    expect(unreplied, isNotEmpty);
    expect(
      unreplied.every((e) => !e.review.hasDirectorReply),
      isTrue,
    );
    expect(
      store.directorReviewInboxItems(lane: ReviewOpsLane.all)
          .where((e) => e.review.hasDirectorReply),
      isNotEmpty,
    );
  });

  test('new24h includes acceptedAt within window only', () async {
    final store = await _boot();
    final now = DateTime.now();
    store.reviews
      ..clear()
      ..addAll([
        CustomerReview(
          id: 'fresh',
          chartId: 'chart-1',
          customerId: '1',
          shopId: store.shop.id,
          originalText: '새 후기',
          status: ReviewStatus.published,
          rating: 4,
          acceptedAt: now.subtract(const Duration(hours: 2)),
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
        CustomerReview(
          id: 'old',
          chartId: 'chart-2',
          customerId: '2',
          shopId: store.shop.id,
          originalText: '오래된 후기',
          status: ReviewStatus.published,
          rating: 5,
          acceptedAt: now.subtract(const Duration(days: 3)),
          createdAt: now.subtract(const Duration(days: 3)),
        ),
      ]);

    final neu =
        store.directorReviewInboxItems(lane: ReviewOpsLane.new24h, now: now);
    expect(neu.map((e) => e.review.id), ['fresh']);
  });

  test('kpi avgRating and naverRate', () async {
    final store = await _boot();
    final now = DateTime.now();
    store.reviews
      ..clear()
      ..addAll([
        CustomerReview(
          id: 'a',
          chartId: 'chart-1',
          customerId: '1',
          shopId: store.shop.id,
          originalText: 'a',
          status: ReviewStatus.published,
          rating: 4,
          naverRegistered: true,
          acceptedAt: now.subtract(const Duration(days: 1)),
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        CustomerReview(
          id: 'b',
          chartId: 'chart-2',
          customerId: '2',
          shopId: store.shop.id,
          originalText: 'b',
          status: ReviewStatus.published,
          rating: 2,
          acceptedAt: now.subtract(const Duration(days: 2)),
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ]);

    final kpi = store.reviewOpsKpi(now: now);
    expect(kpi.inboxTotal, 2);
    expect(kpi.avgRating, 3.0);
    expect(kpi.naverRate, 0.5);
    expect(kpi.weekCount, 2);
    expect(kpi.unreplied, 2);
  });

  test('requestedPending does not double-count reviewed customers', () async {
    final store = await _boot();
    store.reviewRequestedCustomerIds
      ..clear()
      ..addAll({'1', '2', 'ghost-customer'});
    // customer 1,2 have inbox reviews in seed
    expect(store.reviewRequestedPendingCount, 1);

    final unreplied = store.reviewUnrepliedCount;
    // badge inputs: unreplied + pending — ghost only in pending
    expect(unreplied + store.reviewRequestedPendingCount, unreplied + 1);
  });

  test('setNaverRegistered toggles local flag', () async {
    final store = await _boot();
    final target = store.reviews.first;
    await store.setNaverRegistered(
      chartId: target.chartId,
      registered: true,
      composedText: target.displayText,
    );
    expect(store.reviewForChart(target.chartId)?.naverRegistered, isTrue);

    await store.setNaverRegistered(
      chartId: target.chartId,
      registered: false,
    );
    expect(store.reviewForChart(target.chartId)?.naverRegistered, isFalse);
  });
}
