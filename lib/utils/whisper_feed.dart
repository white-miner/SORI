import '../models/community_post.dart';

/// 속삭임 탭 Zone A — 수신자로서 본문을 읽을 수 있는 글 (작성자 본인 글 제외).
List<CommunityPost> whisperIncomingPosts(
  Iterable<CommunityPost> posts, {
  required String? viewerId,
}) {
  if (viewerId == null || viewerId.isEmpty) return const [];
  return posts
      .where(
        (p) =>
            p.isWhisper &&
            !p.isBodyLocked &&
            p.authorUserId != null &&
            p.authorUserId != viewerId,
      )
      .toList()
    ..sort(_byNewest);
}

/// 속삭임 탭 Zone B — 내가 작성한 속삭임.
List<CommunityPost> whisperAuthoredPosts(
  Iterable<CommunityPost> posts, {
  required String? viewerId,
}) {
  if (viewerId == null || viewerId.isEmpty) return const [];
  return posts
      .where((p) => p.isWhisper && p.authorUserId == viewerId)
      .toList()
    ..sort(_byNewest);
}

int _byNewest(CommunityPost a, CommunityPost b) {
  final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  return tb.compareTo(ta);
}
