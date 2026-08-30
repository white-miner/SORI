import '../../models/community_case_item.dart';
import '../../models/community_post.dart';
import '../../models/customer_chart.dart';
import '../../models/home_feed_entry.dart';
import '../../models/seminar_class.dart';
import '../../models/unified_feed_item.dart';
import '../../utils/case_persona.dart';
import '../../utils/relative_time.dart';
import '../feed_media_carousel.dart';

/// Shared display model for Mini / Medium / Original post tiers.
class PostViewData {
  const PostViewData({
    required this.id,
    required this.kind,
    required this.sortAt,
    required this.authorName,
    required this.affiliation,
    required this.categoryLabel,
    required this.bodyText,
    required this.timeLabel,
    this.avatarUrl,
    this.communityLabel,
    this.thumbnailUrl,
    this.bodyLocked = false,
    this.isBoosted = false,
    this.hasActiveMentoring = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.aiContent,
    this.mediaSlides = const [],
    this.heroTag,
    this.caseItem,
    this.post,
    this.seminar,
    this.linkedChartId,
  });

  final String id;
  final PostViewKind kind;
  final DateTime sortAt;
  final String authorName;
  final String affiliation;
  final String categoryLabel;
  final String bodyText;
  final String timeLabel;
  final String? avatarUrl;
  final String? communityLabel;
  final String? thumbnailUrl;
  final bool bodyLocked;
  final bool isBoosted;
  final bool hasActiveMentoring;
  final int likeCount;
  final int commentCount;
  final String? aiContent;
  final List<FeedMediaSlide> mediaSlides;
  final String? heroTag;
  final CommunityCaseItem? caseItem;
  final CommunityPost? post;
  final SeminarClass? seminar;
  final String? linkedChartId;

  String get stableKey => switch (kind) {
        PostViewKind.ba => 'ba:${caseItem!.chart.id}',
        PostViewKind.seminar => 'seminar:${seminar!.id}',
        _ => 'post:${post!.id}',
      };

  PostViewData copyWithEngagement({int? likeCount, int? commentCount}) {
    return PostViewData(
      id: id,
      kind: kind,
      sortAt: sortAt,
      authorName: authorName,
      affiliation: affiliation,
      categoryLabel: categoryLabel,
      bodyText: bodyText,
      timeLabel: timeLabel,
      avatarUrl: avatarUrl,
      communityLabel: communityLabel,
      thumbnailUrl: thumbnailUrl,
      bodyLocked: bodyLocked,
      isBoosted: isBoosted,
      hasActiveMentoring: hasActiveMentoring,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      aiContent: aiContent,
      mediaSlides: mediaSlides,
      heroTag: heroTag,
      caseItem: caseItem,
      post: post,
      seminar: seminar,
      linkedChartId: linkedChartId,
    );
  }

  String? get commentPostId {
    if (post != null) return post!.id;
    if (kind == PostViewKind.ba && caseItem != null) return caseItem!.chart.id;
    final linked = linkedChartId?.trim();
    if (linked != null && linked.isNotEmpty) return linked;
    return null;
  }

  /// PO AI rules: explicit ai_content → chart-tag fallback for linked B/A → hidden.
  String? resolveAiSummary() {
    final explicit = aiContent?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final body = bodyText.trim();
    if (body.isNotEmpty) return null;

    if (kind == PostViewKind.ba && caseItem != null) {
      return _chartTagSummary(caseItem!.chart, caseItem!.careTags);
    }

    final chartId = linkedChartId?.trim();
    if (chartId != null &&
        chartId.isNotEmpty &&
        caseItem != null &&
        caseItem!.chart.id == chartId) {
      return _chartTagSummary(caseItem!.chart, caseItem!.careTags);
    }

    if (post?.sourceChartId?.trim().isNotEmpty == true && caseItem != null) {
      return _chartTagSummary(caseItem!.chart, caseItem!.careTags);
    }

    return null;
  }

  static String? _chartTagSummary(CustomerChart chart, List<String> careTags) {
    final parts = <String>[
      chart.metadataSummaryLine,
      chart.concerns,
      chart.skinType,
      chart.treatmentSummary,
      ...careTags,
      ...chart.careTags,
    ].map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (parts.isEmpty) return null;
    return parts.take(6).join(' · ');
  }

  factory PostViewData.fromUnifiedFeedItem(UnifiedFeedItem item) {
    return switch (item.kind) {
      UnifiedFeedKind.ba => _fromBa(item),
      UnifiedFeedKind.seminar => _fromSeminar(item),
      UnifiedFeedKind.whisper => _fromPost(item, 'Whisper'),
      UnifiedFeedKind.interior => _fromPost(item, '샵 인테리어'),
      UnifiedFeedKind.deviceReview => _fromPost(item, '기기리뷰'),
      UnifiedFeedKind.marketplace => _fromMarketplace(item),
    };
  }

  factory PostViewData.fromHomeFeedEntry(HomeFeedEntry entry) {
    return switch (entry.kind) {
      HomeFeedEntryKind.caseItem => _fromCaseItem(entry.caseItem!),
      HomeFeedEntryKind.seminar => _fromSeminarEntry(entry.seminar!),
      HomeFeedEntryKind.publicWhisper => _fromWhisperEntry(entry.whisperPost!),
    };
  }

  factory PostViewData.fromCaseItem(CommunityCaseItem item) =>
      _fromCaseItem(item);

  static PostViewData _fromBa(UnifiedFeedItem item) {
    final c = item.caseItem!;
    final chart = c.chart;
    final mentoring = c.hasActiveMentoring;
    final body = [
      chart.serviceMenuLabel,
      CasePersona.feedLine(
        chart: chart,
        age: c.customerAge ?? chart.age,
        genderLabel: c.customerGenderLabel ?? chart.gender,
      ),
      chart.treatmentSummary,
    ].where((e) => e.trim().isNotEmpty).join('\n');

    return PostViewData(
      id: chart.id,
      kind: PostViewKind.ba,
      sortAt: item.sortAt,
      authorName: c.displayAuthorNickname,
      affiliation: c.displayShopAffiliation,
      categoryLabel: mentoring ? '멘토링' : 'B/A',
      bodyText: body,
      timeLabel: formatRelativeTime(item.sortAt),
      avatarUrl: _firstNonEmpty([c.authorAvatarUrl, c.shop.profileImageUrl ?? '']),
      communityLabel: mentoring ? '멘토링' : 'B/A',
      thumbnailUrl: chart.afterImageUrl ?? chart.beforeImageUrl,
      isBoosted: item.isBoosted || c.isBoosted,
      hasActiveMentoring: mentoring,
      likeCount: 5 + chart.id.hashCode.abs() % 48,
      mediaSlides: feedSlidesForCase(
        beforeUrl: chart.beforeImageUrl,
        afterUrl: chart.afterImageUrl,
      ),
      heroTag: 'post-ba-${chart.id}',
      caseItem: c,
      linkedChartId: chart.id,
    );
  }

  static PostViewData _fromCaseItem(CommunityCaseItem c) {
    final chart = c.chart.copyWith(
      feedAge: c.customerAge ?? c.chart.feedAge,
      feedGenderLabel: c.customerGenderLabel ?? c.chart.feedGenderLabel,
    );
    final mentoring = c.hasActiveMentoring;
    final body = [
      chart.serviceMenuLabel,
      CasePersona.feedLine(
        chart: chart,
        age: c.customerAge ?? chart.age,
        genderLabel: c.customerGenderLabel ?? chart.gender,
      ),
      if (chart.treatmentSummary.trim().isNotEmpty) chart.treatmentSummary.trim(),
    ].where((e) => e.trim().isNotEmpty).join('\n');

    return PostViewData(
      id: chart.id,
      kind: PostViewKind.ba,
      sortAt: chart.feedPostedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      authorName: c.displayAuthorNickname,
      affiliation: '${c.displayShopAffiliation} · ${chart.relativeTimeLabel}',
      categoryLabel: mentoring ? '멘토링' : 'B/A',
      bodyText: body,
      timeLabel: chart.relativeTimeLabel,
      avatarUrl: c.displayAuthorAvatarUrl,
      communityLabel: mentoring ? '멘토링' : 'B/A',
      thumbnailUrl: chart.afterImageUrl ?? chart.beforeImageUrl,
      isBoosted: c.isBoosted,
      hasActiveMentoring: mentoring,
      likeCount: 5 + chart.id.hashCode.abs() % 48,
      mediaSlides: feedSlidesForCase(
        beforeUrl: chart.beforeImageUrl,
        afterUrl: chart.afterImageUrl,
      ),
      heroTag: 'post-ba-${chart.id}',
      caseItem: c,
      linkedChartId: chart.id,
    );
  }

  static PostViewData _fromSeminar(UnifiedFeedItem item) {
    final s = item.seminar!;
    return PostViewData(
      id: s.id,
      kind: PostViewKind.seminar,
      sortAt: item.sortAt,
      authorName: '세미나',
      affiliation: s.location.trim(),
      categoryLabel: '세미나',
      bodyText: s.title.trim().ifEmpty(s.description),
      timeLabel: formatRelativeTime(item.sortAt),
      communityLabel: '세미나',
      thumbnailUrl: s.additionalImages.isNotEmpty ? s.additionalImages.first : null,
      mediaSlides: s.additionalImages.isNotEmpty
          ? s.additionalImages
              .map((u) => FeedMediaSlide.image(url: u))
              .toList(growable: false)
          : const [],
      seminar: s,
      linkedChartId: s.linkedChartId,
    );
  }

  static PostViewData _fromSeminarEntry(SeminarClass s) {
    return PostViewData(
      id: s.id,
      kind: PostViewKind.seminar,
      sortAt: s.createdAt ?? s.eventDate ?? DateTime.now(),
      authorName: '세미나',
      affiliation: s.location.trim(),
      categoryLabel: '세미나',
      bodyText: s.title.trim().ifEmpty(s.description),
      timeLabel: formatRelativeTime(s.createdAt),
      communityLabel: '세미나',
      thumbnailUrl: s.additionalImages.isNotEmpty ? s.additionalImages.first : null,
      mediaSlides: s.additionalImages.isNotEmpty
          ? s.additionalImages
              .map((u) => FeedMediaSlide.image(url: u))
              .toList(growable: false)
          : const [],
      seminar: s,
      linkedChartId: s.linkedChartId,
    );
  }

  static PostViewData _fromWhisperEntry(CommunityPost p) {
    return _postBase(p, 'Whisper', PostViewKind.whisper);
  }

  static PostViewData _fromPost(UnifiedFeedItem item, String label) {
    final p = item.post!;
    return _postBase(
      p,
      label,
      switch (item.kind) {
        UnifiedFeedKind.whisper => PostViewKind.whisper,
        UnifiedFeedKind.interior => PostViewKind.interior,
        UnifiedFeedKind.deviceReview => PostViewKind.deviceReview,
        _ => PostViewKind.marketplace,
      },
      sortAt: item.sortAt,
      isBoosted: item.isBoosted,
    );
  }

  static PostViewData _fromMarketplace(UnifiedFeedItem item) {
    final p = item.post!;
    final used = item.isMarketplaceUsed;
    final listing = p.listing;
    final price = listing != null ? '${listing.price}원 · ' : '';
    final device = listing?.deviceName.trim() ?? p.title.trim();
    return _postBase(
      p,
      used ? '중고거래' : '제품리뷰',
      PostViewKind.marketplace,
      sortAt: item.sortAt,
      isBoosted: item.isBoosted,
      bodyOverride: '$price${p.body.trim().ifEmpty(device)}',
    );
  }

  static PostViewData _postBase(
    CommunityPost p,
    String label,
    PostViewKind kind, {
    DateTime? sortAt,
    bool isBoosted = false,
    String? bodyOverride,
  }) {
    final locked = p.isBodyLocked;
    final slides = <FeedMediaSlide>[];
    final img = p.primaryImageUrl;
    if (img != null && img.isNotEmpty) {
      slides.add(FeedMediaSlide.image(url: img));
    }
    return PostViewData(
      id: p.id,
      kind: kind,
      sortAt: sortAt ?? p.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      authorName: p.authorDisplayName,
      affiliation: p.shopName.trim(),
      categoryLabel: label,
      bodyText: bodyOverride ??
          (locked
              ? '선택한 수신자에게만 공개된 Whisper입니다.'
              : p.body.trim().ifEmpty(p.title)),
      timeLabel: formatRelativeTime(sortAt ?? p.createdAt),
      avatarUrl: p.shopAvatarUrl,
      communityLabel: label,
      thumbnailUrl: img,
      bodyLocked: locked,
      isBoosted: isBoosted,
      likeCount: p.likeCount,
      commentCount: p.commentCount,
      aiContent: p.aiContent,
      mediaSlides: slides,
      heroTag: 'post-${p.id}',
      post: p,
      linkedChartId: p.sourceChartId,
    );
  }

  static String? _firstNonEmpty(List<String> values) {
    for (final raw in values) {
      final v = raw.trim();
      if (v.isNotEmpty) return v;
    }
    return null;
  }
}

enum PostViewKind {
  ba,
  seminar,
  whisper,
  interior,
  deviceReview,
  marketplace,
}

extension _PostStringExt on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : trim();
}
