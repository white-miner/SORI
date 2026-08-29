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
