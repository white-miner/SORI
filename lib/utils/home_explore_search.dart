import '../models/community_case_item.dart';
import '../models/community_post.dart';
import '../models/subscription.dart';
import '../models/unified_feed_item.dart';
import '../services/unified_feed_engine.dart';

/// 홈 탐색 검색 토큰·랭킹.
abstract final class HomeExploreSearch {
  static List<String> tokens(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .split(RegExp(r'[\s,]+'))
        .map((t) => t.replaceFirst(RegExp(r'^#+'), '').trim())
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
  }

  /// 이름 일치 > 기기/태그 > 본문.
  static int scoreHaystacks({
    required List<String> tokens,
    required String exactName,
    required String tagsDevice,
    required String body,
  }) {
    if (tokens.isEmpty) return 0;
    final name = exactName.toLowerCase();
    final tags = tagsDevice.toLowerCase();
    final text = body.toLowerCase();
    var score = 0;
    for (final t in tokens) {
      if (name == t || name.contains(t)) {
        score += name == t ? 1000 : 400;
      } else if (tags.contains(t)) {
        score += 120;
      } else if (text.contains(t)) {
        score += 40;
      } else {
        return -1;
      }
    }
    return score;
  }

  static int scoreCase(CommunityCaseItem item, List<String> tokens) {
    return scoreHaystacks(
      tokens: tokens,
      exactName: item.shop.name,
      tagsDevice: [
        item.chart.careName,
        item.chart.deviceInfo ?? '',
        ...item.displayCareTags,
      ].join(' '),
      body: [
        item.chart.treatmentSummary,
        item.chart.directorInsight,
        item.personaLine,
        item.review?.displayText ?? '',
      ].join(' '),
    );
  }

  static int scorePost(CommunityPost post, List<String> tokens) {
    final device = post.deviceReview?.deviceName ??
        post.listing?.deviceName ??
        '';
    return scoreHaystacks(
      tokens: tokens,
      exactName: post.shopName,
      tagsDevice: [device, post.title, ...post.styleTags].join(' '),
      body: post.body,
    );
  }

  /// C5 — 통합 피드(추천과 동일 소스) 검색.
  static int scoreUnified(UnifiedFeedItem item, List<String> tokens) {
    if (tokens.isEmpty) return 0;
    final title = UnifiedFeedEngine.gridTitle(item);
    final subtitle = UnifiedFeedEngine.gridSubtitle(item);
    final author = UnifiedFeedEngine.gridAuthorName(item);
    final category = UnifiedFeedEngine.gridCategoryLabel(item);
    switch (item.kind) {
      case UnifiedFeedKind.ba:
        final c = item.caseItem;
        if (c == null) return -1;
        return scoreCase(c, tokens);
      case UnifiedFeedKind.seminar:
        final s = item.seminar;
        return scoreHaystacks(
          tokens: tokens,
          exactName: s?.title ?? title,
          tagsDevice: [category, s?.location ?? ''].join(' '),
          body: [s?.description ?? '', subtitle].join(' '),
        );
      case UnifiedFeedKind.whisper:
      case UnifiedFeedKind.interior:
      case UnifiedFeedKind.deviceReview:
      case UnifiedFeedKind.marketplace:
        final p = item.post;
        if (p != null) {
          final base = scorePost(p, tokens);
          if (base >= 0) return base;
        }
        return scoreHaystacks(
          tokens: tokens,
          exactName: author,
          tagsDevice: [category, title].join(' '),
          body: subtitle,
        );
    }
  }

  static int scoreDirector(DiscoverDirector d, List<String> tokens) {
    return scoreHaystacks(
      tokens: tokens,
      exactName: '${d.nickname} ${d.shopName}',
      tagsDevice: d.address,
      body: d.bio,
    );
  }

  static bool isSearchablePost(CommunityPost post) {
    if (post.isWhisper) return false;
    return post.postType == CommunityPostType.interior ||
        post.postType == CommunityPostType.deviceReview ||
        post.postType == CommunityPostType.caseShare;
  }
}
