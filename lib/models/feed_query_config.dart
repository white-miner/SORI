/// Feed surface query policy — R2 Expand (home vs community).
/// Store cache stays shared; callers slice via [FeedQueryConfig].
enum FeedSurface {
  /// Customer home glance — light discovery only.
  home,

  /// Community plaza — full explore / write / save / boost (when labeled).
  community,
}

class FeedQueryConfig {
  const FeedQueryConfig({
    required this.surface,
    required this.boostAllowed,
    required this.maxRecommendItems,
    required this.showExploreTab,
    required this.showLocalTab,
  });

  final FeedSurface surface;

  /// Home: false. Community: true (existing boost interleave may appear).
  final bool boostAllowed;

  /// Null = no cap (community). Home = 1–3.
  final int? maxRecommendItems;

  final bool showExploreTab;
  final bool showLocalTab;

  static const FeedQueryConfig home = FeedQueryConfig(
    surface: FeedSurface.home,
    boostAllowed: false,
    maxRecommendItems: 3,
    showExploreTab: false,
    showLocalTab: false,
  );

  /// Byte-preserving default for existing UnifiedHomeFeed mounts.
  static const FeedQueryConfig community = FeedQueryConfig(
    surface: FeedSurface.community,
    boostAllowed: true,
    maxRecommendItems: null,
    showExploreTab: true,
    showLocalTab: true,
  );

  static FeedQueryConfig forSurface(FeedSurface surface) {
    return switch (surface) {
      FeedSurface.home => home,
      FeedSurface.community => community,
    };
  }
}
