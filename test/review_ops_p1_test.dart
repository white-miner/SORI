import 'package:flutter_test/flutter_test.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/customer_review.dart';
import 'package:sori/models/review_request_event.dart';
import 'package:sori/services/sori_store.dart';

void main() {
  setUp(() {
    MemorySoriRepository.debugClearReviewRequestEvents();
  });

  Future<SoriStore> boot() async {
    final store = SoriStore(repository: MemorySoriRepository());
    await store.bootstrap();
    return store;
  }

  test('recordReviewRequest creates event with remind_at', () async {
    final store = await boot();
    final event = await store.recordReviewRequest(
      customerId: 'no-review-yet',
      channel: 'qr',
      remindHours: 24,
    );
    expect(event, isNotNull);
    expect(event!.status, ReviewRequestStatus.sent);
    expect(event.channel, ReviewRequestChannel.qr);
    expect(event.remindAt, isNotNull);
    expect(store.isReviewRequested('no-review-yet'), isTrue);
    expect(store.reviewRequestedPendingCount, greaterThan(0));
  });

  test('merging inbox review converts open request events', () async {
    final store = await boot();
    MemorySoriRepository.debugClearReviewRequestEvents();
    store.reviewRequestEvents.clear();
    store.reviewRequestedCustomerIds.clear();

    final customer = store.customers.first;
    await store.recordReviewRequest(customerId: customer.id, channel: 'link');
    expect(
      store.reviewRequestEvents.where((e) => e.status.isOpen),
      isNotEmpty,
    );

    final review = CustomerReview(
      id: 'converted-rev',
      chartId: store.latestChart(customer.id)?.id ?? 'chart-x',
      customerId: customer.id,
      shopId: store.shop.id,
      originalText: '작성 완료된 후기입니다',
      status: ReviewStatus.published,
      rating: 5,
      acceptedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
    // trigger convert via public publish path
    await store.publishShopReview(
      chartId: review.chartId,
      customerId: customer.id,
      text: review.originalText,
      rating: 5,
    );

    expect(
      store.reviewRequestEvents
          .where((e) => e.customerId == customer.id)
          .every((e) => e.status == ReviewRequestStatus.converted),
      isTrue,
    );
  });

  test('careRatingStats ranks by average', () async {
    final store = await boot();
    final now = DateTime.now();
    store.reviews
      ..clear()
      ..addAll([
        CustomerReview(
          id: 'c1',
          chartId: 'chart-1',
          customerId: '1',
          shopId: store.shop.id,
          originalText: 'a',
          status: ReviewStatus.published,
          rating: 5,
          acceptedAt: now,
          createdAt: now,
        ),
        CustomerReview(
          id: 'c2',
          chartId: 'chart-2',
          customerId: '2',
          shopId: store.shop.id,
          originalText: 'b',
          status: ReviewStatus.published,
          rating: 3,
          acceptedAt: now,
          createdAt: now,
        ),
      ]);
    final stats = store.careRatingStats();
    expect(stats, isNotEmpty);
    expect(stats.first.avgRating, greaterThanOrEqualTo(stats.last.avgRating));
  });

  test('kpi replyRate and remindDue', () async {
    final store = await boot();
    final now = DateTime.now();
    store.reviews
      ..clear()
      ..addAll([
        CustomerReview(
          id: 'r1',
          chartId: 'chart-1',
          customerId: '1',
          shopId: store.shop.id,
          originalText: 'x',
          status: ReviewStatus.published,
          rating: 4,
          directorReply: 'thanks',
          acceptedAt: now,
          createdAt: now,
        ),
        CustomerReview(
          id: 'r2',
          chartId: 'chart-2',
          customerId: '2',
          shopId: store.shop.id,
          originalText: 'y',
          status: ReviewStatus.published,
          rating: 4,
          acceptedAt: now,
          createdAt: now,
        ),
      ]);
    final kpi = store.reviewOpsKpi(now: now);
    expect(kpi.replyRate, 0.5);

    await store.recordReviewRequest(
      customerId: 'ghost',
      remindHours: 1,
    );
    // Force due: rewrite remindAt in memory list
    final e = store.reviewRequestEvents.first;
    store.reviewRequestEvents[0] = ReviewRequestEvent(
      id: e.id,
      shopId: e.shopId,
      customerId: e.customerId,
      channel: e.channel,
      status: e.status,
      sentAt: e.sentAt,
      remindAt: now.subtract(const Duration(minutes: 1)),
    );
    expect(store.reviewRemindDueCount, 1);
    expect(store.reviewOpsKpi(now: now).remindDue, 1);
  });
}
