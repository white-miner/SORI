import 'package:flutter_test/flutter_test.dart';

import 'package:sori/content_atomizer/content_atomizer.dart';
import 'package:sori/content_atomizer/models/post_draft.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/features/habit/habit_feed_engine.dart';
import 'package:sori/features/publish_rail/publish_rail_service.dart';
import 'package:sori/models/community_post.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/models/session_user.dart';
import 'package:sori/models/unified_feed_item.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/visit_kernel/models/visit_session.dart';

void main() {
  group('HabitFeedEngine', () {
    test('mentoringLive detects styleTags on case_share posts', () async {
      final store = SoriStore();
      await store.bootstrap(repository: MemorySoriRepository());
      store.session = const SessionUser(
        role: UserRole.director,
        name: '테스트',
        phone: '010',
        provider: SocialProvider.kakao,
        onboardingComplete: true,
        shopSetupComplete: true,
        activeMode: UserRole.director,
      );

      final post = await store.createCommunityPost(
        postType: CommunityPostType.caseShare,
        title: '이 케이스, 다음엔?',
        body: '비슷한 고민 겪었던 원장님 조언 부탁드려요',
        styleTags: const ['멘토링', '조언구함'],
      );
      expect(post, isNotNull);
      await store.refreshUnifiedCommunityFeed(force: true);

      final live = HabitFeedEngine.mentoringLiveItems(store);
      expect(live.any(HabitFeedEngine.isMentoringAsk), isTrue);
    });

    test('sameStruggle picks whisper items', () async {
      final store = SoriStore();
      await store.bootstrap(repository: MemorySoriRepository());

      final post = await store.createCommunityPost(
        postType: CommunityPostType.whisper,
        title: 'Whisper',
        body: '오늘도 따뜻한 케어',
        styleTags: const ['감성', '비식별'],
      );
      expect(post, isNotNull);
      await store.refreshUnifiedCommunityFeed(force: true);

      final struggle = HabitFeedEngine.sameStruggleItems(store);
      expect(struggle, isNotEmpty);
      expect(struggle.every(HabitFeedEngine.isSameStruggle), isTrue);
    });

    test('storyRailItems returns ranked visible feed', () async {
      final store = SoriStore();
      await store.bootstrap(repository: MemorySoriRepository());
      await store.refreshUnifiedCommunityFeed(force: true);

      final rail = HabitFeedEngine.storyRailItems(store, limit: 5);
      expect(rail.length, lessThanOrEqualTo(5));
    });
  });

  group('InsightsDigestEngine', () {
    test('snapshot aggregates own shop posts', () async {
      final store = SoriStore();
      await store.bootstrap(repository: MemorySoriRepository());
      store.session = const SessionUser(
        role: UserRole.director,
        name: '김원장',
        phone: '010',
        provider: SocialProvider.kakao,
        onboardingComplete: true,
        shopSetupComplete: true,
        activeMode: UserRole.director,
      );

      await store.createCommunityPost(
        postType: CommunityPostType.whisper,
        title: 'Tip',
        body: '홈케어 팁',
        styleTags: const ['홈케어'],
      );

      final snap = InsightsDigestEngine.snapshot(store);
      expect(snap.postCount, greaterThanOrEqualTo(1));
    });
  });

  group('Mentoring publish rail', () {
    test('mentoringRequest publishes case_share not RPC on own chart', () async {
      final store = SoriStore();
      await store.bootstrap(repository: MemorySoriRepository());
      store.session = const SessionUser(
        role: UserRole.director,
        name: '김원장',
        phone: '010-1234-5678',
        provider: SocialProvider.kakao,
        onboardingComplete: true,
        shopSetupComplete: true,
        activeMode: UserRole.director,
      );

      if (store.customers.isEmpty) return;

      final customer = store.customers.first;
      final chart = CustomerChart(
        id: 'habit-chart-1',
        shopId: store.shop.id,
        customerId: customer.id,
        visitNumber: 1,
        careName: '테스트',
        concernChips: const ['건조/장벽'],
        beforeImageUrl: 'https://example.com/before.jpg',
        consentMandatory: true,
        consentPhoto: true,
        consentMarketing: true,
        signatureUrl: 'https://example.com/sig.png',
      );
      store.charts.add(chart);

      final session = VisitSession(
        id: 'visit-habit-1',
        shopId: store.shop.id,
        customerId: customer.id,
        customerName: customer.name,
        chartDraftId: chart.id,
        startedAt: DateTime.now(),
      );

      final atomized = ContentAtomizer.atomize(
        session: session,
        chart: chart,
        shopName: store.shop.name,
      );

      final mentoringDraft = atomized.drafts
          .firstWhere((d) => d.kind == PostDraftKind.mentoringRequest);

      expect(mentoringDraft.enabled, isTrue);

      final before = store.communityPosts.length;
      final result = await PublishRailService.publishAll(
        store: store,
        chart: chart,
        drafts: [mentoringDraft],
      );

      expect(result.published, 1);
      expect(store.communityPosts.length, greaterThan(before));
      final published = store.communityPosts.last;
      expect(published.postType, CommunityPostType.caseShare);
      expect(
        published.styleTags.any((t) => t.contains('멘토링')),
        isTrue,
      );
    });
  });

  group('UnifiedFeedItem mentoring filter', () {
    test('matchesFilter mentoring includes styleTags', () {
      final post = CommunityPost(
        id: 'p1',
        shopId: 's1',
        authorUserId: 'u1',
        postType: CommunityPostType.caseShare,
        title: 'ask',
        body: 'help',
        styleTags: const ['멘토링', '조언구함'],
      );
      final item = UnifiedFeedItem.post(post, UnifiedFeedKind.whisper);

      expect(item.matchesFilter(CommunityFeedFilter.mentoring), isTrue);
    });
  });
}
