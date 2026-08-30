import 'package:flutter/material.dart';

import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../widgets/community_comments_section.dart';
import '../widgets/post/post_action_row.dart';
import '../widgets/post/post_ai_content.dart';
import '../widgets/post/post_header.dart';
import '../widgets/post/post_media_section.dart';
import '../widgets/post/post_view_data.dart';

/// Tier C — full post detail with comments expanded on mount.
class SoriPostOriginalPage extends StatefulWidget {
  const SoriPostOriginalPage({
    super.key,
    required this.data,
    required this.store,
    this.liked = false,
    this.bookmarked = false,
    this.onLike,
    this.onComment,
    this.onBookmark,
    this.onMentoring,
  });

  final PostViewData data;
  final SoriStore store;
  final bool liked;
  final bool bookmarked;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onBookmark;
  final VoidCallback? onMentoring;

  static Future<void> open(
    BuildContext context, {
    required PostViewData data,
    required SoriStore store,
    bool liked = false,
    bool bookmarked = false,
    VoidCallback? onLike,
    VoidCallback? onComment,
    VoidCallback? onBookmark,
    VoidCallback? onMentoring,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => SoriPostOriginalPage(
          data: data,
          store: store,
          liked: liked,
          bookmarked: bookmarked,
          onLike: onLike,
          onComment: onComment,
          onBookmark: onBookmark,
          onMentoring: onMentoring,
        ),
      ),
    );
  }

  @override
  State<SoriPostOriginalPage> createState() => _SoriPostOriginalPageState();
}

class _SoriPostOriginalPageState extends State<SoriPostOriginalPage> {
  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final postId = data.commentPostId;

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        backgroundColor: SoriTokens.background,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            const Text(
              '포스트',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: SoriTokens.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Text(
                '커뮤니티 바로가기',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: SoriTokens.primary,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PostHeader(data: data),
            PostMediaSection(
              slides: data.mediaSlides,
              heroTag: data.heroTag,
              maxHeight: 420,
            ),
            if (data.bodyText.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  data.bodyText.trim(),
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: SoriTokens.textPrimary,
                  ),
                ),
              ),
            PostAiContent(
              data: data,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            ),
            PostActionRow(
              liked: widget.liked,
              bookmarked: widget.bookmarked,
              likeCount: data.likeCount,
              commentCount: data.commentCount,
              showMentoring: data.hasActiveMentoring,
              onLike: widget.onLike ?? () {},
              onComment: widget.onComment ?? () {},
              onBookmark: widget.onBookmark ?? () {},
              onMentoring: widget.onMentoring,
            ),
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '댓글 및 추가 정보',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: SoriTokens.textPrimary,
                ),
              ),
            ),
            if (postId != null)
              CommunityCommentsSection(
                store: widget.store,
                postId: postId,
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Text(
                  data.kind == PostViewKind.ba
                      ? 'B/A 케이스 댓글은 홈 피드에서 확인할 수 있어요.'
                      : '댓글을 불러올 수 없어요.',
                  style: const TextStyle(
                    color: SoriTokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
