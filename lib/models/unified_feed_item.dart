import 'community_case_item.dart';
import 'community_post.dart';
import 'seminar_class.dart';

/// Unified community feed filter — tab = local filter, no refetch.
enum CommunityFeedFilter {
  all,
  whisper,
  interior,
  deviceReview,
  marketplace,
  seminar,
  ba;

  String get label => switch (this) {
        CommunityFeedFilter.all => '전체',
        CommunityFeedFilter.whisper => 'Whisper',
        CommunityFeedFilter.interior => '인테리어',
        CommunityFeedFilter.deviceReview => '기기 리뷰',
        CommunityFeedFilter.marketplace => '중고·신상',
        CommunityFeedFilter.seminar => '세미나',
        CommunityFeedFilter.ba => 'B/A',
      };

  String get dbFilter => switch (this) {
        CommunityFeedFilter.all => 'all',
        CommunityFeedFilter.whisper => 'whisper',
        CommunityFeedFilter.interior => 'interior',
        CommunityFeedFilter.deviceReview => 'device_review',
        CommunityFeedFilter.marketplace => 'marketplace',
        CommunityFeedFilter.seminar => 'seminar',
        CommunityFeedFilter.ba => 'ba',
      };

  static CommunityFeedFilter fromLegacySegment(int? index) {
    return switch (index) {
      1 => CommunityFeedFilter.whisper,
      2 => CommunityFeedFilter.interior,
      3 => CommunityFeedFilter.deviceReview,
      4 => CommunityFeedFilter.marketplace,
      5 => CommunityFeedFilter.seminar,
      _ => CommunityFeedFilter.all,
    };
  }
}

enum UnifiedFeedKind {
  ba,
  seminar,
  whisper,
  interior,
  deviceReview,
  marketplace;

  String get dbValue => switch (this) {
        UnifiedFeedKind.ba => 'ba',
        UnifiedFeedKind.seminar => 'seminar',
        UnifiedFeedKind.whisper => 'whisper',
        UnifiedFeedKind.interior => 'interior',
        UnifiedFeedKind.deviceReview => 'device_review',
        UnifiedFeedKind.marketplace => 'marketplace',
      };

  static UnifiedFeedKind? fromDb(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'ba':
      case 'case_share':
        return UnifiedFeedKind.ba;
      case 'seminar':
        return UnifiedFeedKind.seminar;
      case 'whisper':
        return UnifiedFeedKind.whisper;
      case 'interior':
        return UnifiedFeedKind.interior;
      case 'device_review':
      case 'device-review':
        return UnifiedFeedKind.deviceReview;
      case 'marketplace':
        return UnifiedFeedKind.marketplace;
      default:
        return null;
    }
  }
}

/// Single row in the unified community feed (federated).
class UnifiedFeedItem {
  const UnifiedFeedItem({
    required this.kind,
    required this.id,
    required this.sortAt,
    this.caseItem,
    this.seminar,
    this.post,
    this.isBoosted = false,
  });

  final UnifiedFeedKind kind;
  final String id;
  final DateTime sortAt;
  final CommunityCaseItem? caseItem;
  final SeminarClass? seminar;
  final CommunityPost? post;
  final bool isBoosted;

  String get stableKey => switch (kind) {
        UnifiedFeedKind.ba => 'ba:${caseItem!.chart.id}',
        UnifiedFeedKind.seminar => 'seminar:${seminar!.id}',
        UnifiedFeedKind.whisper ||
        UnifiedFeedKind.interior ||
        UnifiedFeedKind.deviceReview ||
        UnifiedFeedKind.marketplace =>
          'post:${post!.id}',
      };

  /// Boost placement target id (059 interleave).
  String get boostTargetId => switch (kind) {
        UnifiedFeedKind.ba => caseItem!.chart.id,
        UnifiedFeedKind.seminar => seminar!.id,
        _ => post!.id,
      };

  bool matchesFilter(CommunityFeedFilter filter) {
    if (filter == CommunityFeedFilter.all) return true;
    return switch (filter) {
      CommunityFeedFilter.whisper => kind == UnifiedFeedKind.whisper,
      CommunityFeedFilter.interior => kind == UnifiedFeedKind.interior,
      CommunityFeedFilter.deviceReview => kind == UnifiedFeedKind.deviceReview,
      CommunityFeedFilter.marketplace => kind == UnifiedFeedKind.marketplace,
      CommunityFeedFilter.seminar => kind == UnifiedFeedKind.seminar,
      CommunityFeedFilter.ba => kind == UnifiedFeedKind.ba,
      CommunityFeedFilter.all => true,
    };
  }

  UnifiedFeedItem copyWith({bool? isBoosted}) {
    return UnifiedFeedItem(
      kind: kind,
      id: id,
      sortAt: sortAt,
      caseItem: caseItem,
      seminar: seminar,
      post: post,
      isBoosted: isBoosted ?? this.isBoosted,
    );
  }

  factory UnifiedFeedItem.ba(CommunityCaseItem item) {
    return UnifiedFeedItem(
      kind: UnifiedFeedKind.ba,
      id: item.chart.id,
      sortAt: item.chart.feedPostedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      caseItem: item,
    );
  }

  factory UnifiedFeedItem.seminar(SeminarClass seminar) {
    return UnifiedFeedItem(
      kind: UnifiedFeedKind.seminar,
      id: seminar.id,
      sortAt: seminar.createdAt ??
          seminar.eventDate ??
          DateTime.fromMillisecondsSinceEpoch(0),
      seminar: seminar,
    );
  }

  factory UnifiedFeedItem.post(CommunityPost post, UnifiedFeedKind kind) {
    return UnifiedFeedItem(
      kind: kind,
      id: post.id,
      sortAt: post.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      post: post,
    );
  }
}
