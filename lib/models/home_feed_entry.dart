import 'community_case_item.dart';
import 'community_post.dart';
import 'seminar_class.dart';

/// Unified home feed row — B/A case, seminar recruitment, or public Whisper.
enum HomeFeedEntryKind { caseItem, seminar, publicWhisper }

class HomeFeedEntry {
  const HomeFeedEntry._({
    required this.kind,
    required this.sortAt,
    this.caseItem,
    this.seminar,
    this.whisperPost,
  });

  final HomeFeedEntryKind kind;
  final DateTime sortAt;
  final CommunityCaseItem? caseItem;
  final SeminarClass? seminar;
  final CommunityPost? whisperPost;

  factory HomeFeedEntry.caseItem(CommunityCaseItem item) {
    final at = item.chart.feedPostedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return HomeFeedEntry._(
      kind: HomeFeedEntryKind.caseItem,
      sortAt: at,
      caseItem: item,
    );
  }

  factory HomeFeedEntry.seminar(SeminarClass seminar) {
    return HomeFeedEntry._(
      kind: HomeFeedEntryKind.seminar,
      sortAt: seminar.createdAt ?? seminar.eventDate ?? DateTime.now(),
      seminar: seminar,
    );
  }

  factory HomeFeedEntry.publicWhisper(CommunityPost post) {
    return HomeFeedEntry._(
      kind: HomeFeedEntryKind.publicWhisper,
      sortAt: post.createdAt ?? DateTime.now(),
      whisperPost: post,
    );
  }

  String get stableKey => switch (kind) {
        HomeFeedEntryKind.caseItem => 'case:${caseItem!.chart.id}',
        HomeFeedEntryKind.seminar => 'seminar:${seminar!.id}',
        HomeFeedEntryKind.publicWhisper => 'whisper:${whisperPost!.id}',
      };
}
