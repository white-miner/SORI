import 'package:flutter/material.dart';

import '../../services/sori_store.dart';
import '../../theme/sori_date_picker.dart';
import '../../theme/sori_tokens.dart';
import '../widgets/community_comments_section.dart';
import '../widgets/post/post_action_row.dart';
import '../widgets/post/post_ai_content.dart';
import '../widgets/post/post_header.dart';
import '../widgets/post/post_interaction_sidebar.dart';
import '../widgets/post/post_layout_breakpoints.dart';
import '../widgets/post/post_media_section.dart';
import '../widgets/post/post_view_data.dart';

/// Tier C — full post detail; desktop ≥1024px uses split-pane + sticky comments.
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
    this.onBoost,
  });

  final PostViewData data;
  final SoriStore store;
  final bool liked;
  final bool bookmarked;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onBookmark;
  final VoidCallback? onMentoring;
  final VoidCallback? onBoost;

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
    VoidCallback? onBoost,
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
          onBoost: onBoost,
        ),
      ),
    );
  }

  @override
  State<SoriPostOriginalPage> createState() => _SoriPostOriginalPageState();
}

class _SoriPostOriginalPageState extends State<SoriPostOriginalPage> {
  final _mobileCommentsKey = GlobalKey();

  void _scrollToComments() {
    final ctx = _mobileCommentsKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop =
              PostLayoutBreakpoints.isDesktopLayout(constraints.maxWidth);

          if (isDesktop) {
            if (postId != null) {
              return _DesktopSplitBody(
                height: constraints.maxHeight,
                data: data,
                store: widget.store,
                postId: postId,
                liked: widget.liked,
                bookmarked: widget.bookmarked,
                onLike: widget.onLike ?? () {},
                onComment: widget.onComment ?? _scrollToComments,
                onBookmark: widget.onBookmark ?? () {},
                onMentoring: widget.onMentoring,
                onBoost: widget.onBoost,
              );
            }
            return SingleChildScrollView(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: PostLayoutBreakpoints.contentMaxWidth,
                  ),
                  child: _PostMainColumn(
                    data: data,
                    store: widget.store,
                    imageFit: BoxFit.contain,
                    liked: widget.liked,
                    bookmarked: widget.bookmarked,
                    onLike: widget.onLike ?? () {},
                    onComment: widget.onComment ?? _scrollToComments,
                    onBookmark: widget.onBookmark ?? () {},
                    onMentoring: widget.onMentoring,
                    onBoost: widget.onBoost,
                  ),
                ),
              ),
            );
          }

          return _MobileStackBody(
            data: data,
            store: widget.store,
            postId: postId,
            commentsKey: _mobileCommentsKey,
            liked: widget.liked,
            bookmarked: widget.bookmarked,
            onLike: widget.onLike ?? () {},
            onComment: widget.onComment ?? _scrollToComments,
            onBookmark: widget.onBookmark ?? () {},
            onMentoring: widget.onMentoring,
            onBoost: widget.onBoost,
          );
        },
      ),
    );
  }
}

class _DesktopSplitBody extends StatelessWidget {
  const _DesktopSplitBody({
    required this.height,
    required this.data,
    required this.store,
    required this.postId,
    required this.liked,
    required this.bookmarked,
    required this.onLike,
    required this.onComment,
    required this.onBookmark,
    this.onMentoring,
    this.onBoost,
  });

  final double height;
  final PostViewData data;
  final SoriStore store;
  final String postId;
  final bool liked;
  final bool bookmarked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onBookmark;
  final VoidCallback? onMentoring;
  final VoidCallback? onBoost;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        key: const Key('desktop-split-pane-bundle'),
        constraints: const BoxConstraints(
          maxWidth: PostLayoutBreakpoints.splitPaneMaxWidth,
        ),
        child: SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: PostLayoutBreakpoints.contentMaxWidth,
                      ),
                      child: _PostMainColumn(
                        // PO: Header always above media on left post column.
                        data: data,
                        store: store,
                        imageFit: BoxFit.contain,
                        liked: liked,
                        bookmarked: bookmarked,
                        onLike: onLike,
                        onComment: onComment,
                        onBookmark: onBookmark,
                        onMentoring: onMentoring,
                        onBoost: onBoost,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: PostLayoutBreakpoints.splitPaneGap),
              SizedBox(
                width: PostLayoutBreakpoints.sidebarWidth,
                height: height,
                child: PostInteractionSidebar(
                  data: data,
                  store: store,
                  postId: postId,
                  onMentoring: onMentoring,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileStackBody extends StatelessWidget {
  const _MobileStackBody({
    required this.data,
    required this.store,
    required this.postId,
    required this.commentsKey,
    required this.liked,
    required this.bookmarked,
    required this.onLike,
    required this.onComment,
    required this.onBookmark,
    this.onMentoring,
    this.onBoost,
  });

  final PostViewData data;
  final SoriStore store;
  final String? postId;
  final GlobalKey commentsKey;
  final bool liked;
  final bool bookmarked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onBookmark;
  final VoidCallback? onMentoring;
  final VoidCallback? onBoost;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PostMainColumn(
            data: data,
            store: store,
            liked: liked,
            bookmarked: bookmarked,
            onLike: onLike,
            onComment: onComment,
            onBookmark: onBookmark,
            onMentoring: onMentoring,
            onBoost: onBoost,
          ),
          if (postId != null) ...[
            const Divider(height: 24),
            KeyedSubtree(
              key: commentsKey,
              child: CommunityCommentsSection(
                store: store,
                postId: postId!,
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// Forced render order (PO image_35): Header → Media → FullText → ActionDock.
class _PostMainColumn extends StatelessWidget {
  const _PostMainColumn({
    required this.data,
    required this.store,
    required this.liked,
    required this.bookmarked,
    required this.onLike,
    required this.onComment,
    required this.onBookmark,
    this.onMentoring,
    this.onBoost,
    this.imageFit = BoxFit.cover,
  });

  final PostViewData data;
  final SoriStore store;
  final bool liked;
  final bool bookmarked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onBookmark;
  final VoidCallback? onMentoring;
  final VoidCallback? onBoost;
  final BoxFit imageFit;

  @override
  Widget build(BuildContext context) {
    // Wrap-content card — height = Header+Media+Text+Dock only; off-white shows below.
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: SoriGlassPanel(
        borderRadius: 20,
        child: Column(
          key: const Key('post-original-main-column'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Item 1 — PostHeader
            PostHeader(data: data, store: store),
            // Item 2 — PostMedia
            PostMediaSection(
              slides: data.mediaSlides,
              heroTag: data.heroTag,
              maxHeight: 420,
              imageFit: imageFit,
            ),
            // Item 3 — PostFullText (no maxLines truncation)
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
            // Item 4 — Action dock
            PostActionRow(
              liked: liked,
              bookmarked: bookmarked,
              likeCount: data.likeCount,
              commentCount: data.commentCount,
              mentoringActive: data.hasActiveMentoring,
              isBoosted: data.isBoosted,
              onLike: onLike,
              onComment: onComment,
              onBookmark: onBookmark,
              onMentoring: onMentoring ?? () {},
              onBoost: onBoost ?? () {},
            ),
          ],
        ),
      ),
    );
  }
}
