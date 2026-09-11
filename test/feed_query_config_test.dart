import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/models/feed_query_config.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/services/unified_feed_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('FeedQueryConfig home forbids boost and caps recommend', () {
    expect(FeedQueryConfig.home.boostAllowed, isFalse);
    expect(FeedQueryConfig.home.maxRecommendItems, 3);
    expect(FeedQueryConfig.home.showExploreTab, isFalse);
    expect(FeedQueryConfig.home.showLocalTab, isFalse);
  });

  test('FeedQueryConfig community preserves full plaza defaults', () {
    expect(FeedQueryConfig.community.boostAllowed, isTrue);
    expect(FeedQueryConfig.community.maxRecommendItems, isNull);
    expect(FeedQueryConfig.community.showExploreTab, isTrue);
    expect(FeedQueryConfig.community.showLocalTab, isTrue);
  });

  test('recommendItems home strips boost and caps length', () async {
    final store = SoriStore();
    await store.refreshUnifiedCommunityFeed(force: true);

    final community = UnifiedFeedEngine.recommendItems(
      store,
      config: FeedQueryConfig.community,
    );
    final home = UnifiedFeedEngine.recommendItems(
      store,
      config: FeedQueryConfig.home,
    );

    expect(home.every((e) => !e.isBoosted), isTrue);
    expect(home.length, lessThanOrEqualTo(3));
    expect(home.length, lessThanOrEqualTo(community.length));
    // Community path stays uncapped relative to visible cache.
    expect(
      community.length,
      store.unifiedCommunityFeed.where(store.isUnifiedFeedItemVisible).length,
    );
  });
}
