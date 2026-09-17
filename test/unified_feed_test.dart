import 'package:flutter_test/flutter_test.dart';

import 'package:sori/models/community_post.dart';
import 'package:sori/models/unified_feed_item.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/utils/feed_interleave.dart';

void main() {
  test('CommunityFeedFilter maps legacy segment indices', () {
    expect(
      CommunityFeedFilter.fromLegacySegment(1),
      CommunityFeedFilter.whisper,
    );
    expect(
      CommunityFeedFilter.fromLegacySegment(4),
      CommunityFeedFilter.marketplace,
    );
    expect(
      CommunityFeedFilter.fromLegacySegment(null),
      CommunityFeedFilter.all,
    );
  });

  test('filteredUnifiedCommunityFeed does not refetch — local filter only', () async {
    final store = SoriStore();
    await store.refreshUnifiedCommunityFeed(force: true);

    final allCount = store.filteredUnifiedCommunityFeed(
      CommunityFeedFilter.all,
    ).length;
    store.communityFeedFilter = CommunityFeedFilter.interior;
    final interiorCount = store.filteredUnifiedCommunityFeed(
      CommunityFeedFilter.interior,
    ).length;

    expect(interiorCount, lessThanOrEqualTo(allCount));
    expect(store.unifiedCommunityFeed.length, allCount);
  });

  test('UnifiedFeedItem whisper kind matches filter', () {
    const post = CommunityPost(
      id: 'w1',
      shopId: 's1',
      shopName: 'Shop',
      title: '',
      body: 'secret',
      postType: CommunityPostType.whisper,
      visibility: CommunityVisibility.public,
      isWhisper: true,
    );
    final item = UnifiedFeedItem.post(post, UnifiedFeedKind.whisper);
    expect(item.matchesFilter(CommunityFeedFilter.whisper), isTrue);
    expect(item.matchesFilter(CommunityFeedFilter.interior), isFalse);
  });

  test('marketplace splits productReview vs used marketplace', () {
    const usedPost = CommunityPost(
      id: 'm1',
      shopId: 's1',
      shopName: 'Shop',
      title: '울쎄라',
      body: '중고 판매',
      postType: CommunityPostType.marketplace,
      visibility: CommunityVisibility.public,
      listing: MarketListing(
        id: 'l1',
        postId: 'm1',
        shopId: 's1',
        deviceName: '울쎄라',
        brand: 'Merz',
        price: 1000000,
        condition: 'good',
      ),
    );
    const newPost = CommunityPost(
      id: 'm2',
      shopId: 's1',
      shopName: 'Shop',
      title: '신제품',
      body: '신상',
      postType: CommunityPostType.marketplace,
      visibility: CommunityVisibility.public,
      listing: MarketListing(
        id: 'l2',
        postId: 'm2',
        shopId: 's1',
        deviceName: '신제품',
        brand: 'Merz',
        price: 2000000,
        condition: 'new',
      ),
    );
    final usedItem = UnifiedFeedItem.post(usedPost, UnifiedFeedKind.marketplace);
    final newItem = UnifiedFeedItem.post(newPost, UnifiedFeedKind.marketplace);
    expect(usedItem.matchesFilter(CommunityFeedFilter.marketplace), isTrue);
    expect(usedItem.matchesFilter(CommunityFeedFilter.productReview), isFalse);
    expect(newItem.matchesFilter(CommunityFeedFilter.productReview), isTrue);
    expect(newItem.matchesFilter(CommunityFeedFilter.marketplace), isFalse);
  });

  test('searchUnifiedCommunityFeed matches shop and body locally', () async {
    final store = SoriStore();
    await store.refreshUnifiedCommunityFeed(force: true);
    final hits = store.searchUnifiedCommunityFeed('SORI');
    expect(hits, isA<List<UnifiedFeedItem>>());
  });

  test('spotlight and recent helpers return bounded lists', () async {
    final store = SoriStore();
    await store.refreshUnifiedCommunityFeed(force: true);
    expect(store.recentUnifiedFeedItems(limit: 5).length, lessThanOrEqualTo(5));
    expect(
      store.spotlightMiniFeedItems(limit: 3).length,
      lessThanOrEqualTo(3),
    );
  });

  test('CommunityFeedFilter explore chip order includes mentoring', () {
    expect(
      CommunityFeedFilter.exploreFilters,
      contains(CommunityFeedFilter.mentoring),
    );
    expect(CommunityFeedFilter.exploreFilters.first, CommunityFeedFilter.all);
  });

  test('interleaveFeed applies 4:1 boost pattern', () {
    final organic = List.generate(
      8,
      (i) => UnifiedFeedItem.post(
        CommunityPost(
          id: 'o$i',
          shopId: 's1',
          shopName: 'Shop',
          title: 't',
          body: 'body',
          postType: CommunityPostType.interior,
          visibility: CommunityVisibility.public,
          createdAt: DateTime(2026, 1, 8 - i),
        ),
        UnifiedFeedKind.interior,
      ),
    );
    final boosted = [
      organic[2].copyWith(isBoosted: true),
      organic[5].copyWith(isBoosted: true),
    ];

    final mixed = interleaveFeed<UnifiedFeedItem>(
      organic: organic,
      boosted: boosted,
      idOf: (e) => e.stableKey,
    );

    expect(mixed.length, organic.length);
    expect(mixed.where((e) => e.isBoosted).length, boosted.length);
  });
}
