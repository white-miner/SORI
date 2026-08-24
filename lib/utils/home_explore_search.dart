import '../models/community_case_item.dart';
import '../models/community_post.dart';
import '../models/subscription.dart';

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
