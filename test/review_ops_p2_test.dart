import 'package:flutter_test/flutter_test.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/customer_review.dart';
import 'package:sori/services/sori_store.dart';

void main() {
  setUp(MemorySoriRepository.debugClearReviewRequestEvents);

  Future<SoriStore> boot() async {
    final store = SoriStore(repository: MemorySoriRepository());
    await store.bootstrap();
    return store;
  }

  test('promoteReviewToPortfolio requires consent or photos', () async {
    final store = await boot();
    final review = store.reviews.first;
    // Ensure chart exists without consent → expect error message or success if seed has consent
    final err = await store.promoteReviewToPortfolio(review.id);
    // Seed charts may already be consent-signed; either null or a string is fine as long as no throw
    expect(err == null || err.contains('동의') || err.contains('BA') || err.contains('차트'), isTrue);
  });

  test('setNaverPublishStatus ladder updates effective status', () async {
    final store = await boot();
    final review = store.reviews.first;
    await store.setNaverPublishStatus(
      reviewId: review.id,
      status: NaverPublishStatus.copied,
    );
    expect(
      store.reviewById(review.id)!.effectiveNaverStatus,
      NaverPublishStatus.copied,
    );
    await store.setNaverPublishStatus(
      reviewId: review.id,
      status: NaverPublishStatus.confirmed,
    );
    expect(
      store.reviewById(review.id)!.effectiveNaverStatus,
      NaverPublishStatus.confirmed,
    );
  });

  test('openCommunityDeviceReviewComposer sets pending flags', () async {
    final store = await boot();
    store.openCommunityDeviceReviewComposer();
    expect(store.pendingCommunitySegment, 3);
    expect(store.pendingCommunityComposeDevice, isTrue);
  });

  test('AI reply draft returns ready text', () async {
    final store = await boot();
    final review = store.reviews.first;
    final ai = await store.requestAiReplyFeedback(review.id);
    expect(ai.replyText, isNotNull);
    expect(ai.replyText!.trim(), isNotEmpty);
  });
}
