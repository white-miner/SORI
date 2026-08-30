import 'package:flutter/material.dart';

import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../utils/post_navigation.dart';
import 'post_action_row.dart';
import 'post_ai_content.dart';
import 'post_header.dart';
import 'post_media_section.dart';
import 'post_view_data.dart';

/// Tier A — high-density mini card (Community + SORI Spot).
class SoriPostMini extends StatelessWidget {
  /// Horizontal strip height — PO: action row must not clip.
  static const double horizontalStripHeight = 260;

  const SoriPostMini({
    super.key,
    required this.data,
    required this.store,
    this.horizontal = false,
    this.width,
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
  final bool horizontal;
  final double? width;
  final bool liked;
  final bool bookmarked;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onBookmark;
  final VoidCallback? onMentoring;
  final VoidCallback? onBoost;

  void _openOriginal(BuildContext context) {
    openPostOriginal(context, data: data, store: store);
  }

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openOriginal(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            PostHeader(data: data, dense: true),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data.mediaSlides.isNotEmpty) ...[
                    PostMiniThumbnail(slides: data.mediaSlides),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.bodyText,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: data.bodyLocked
                                ? SoriTokens.textTertiary
                                : SoriTokens.textPrimary,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => _openOriginal(context),
                            style: TextButton.styleFrom(
                              foregroundColor: SoriTokens.primary,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              '…더 보기',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            PostAiContent(
              data: data,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            ),
            PostActionRow(
              compact: true,
              liked: liked,
              bookmarked: bookmarked,
              likeCount: data.likeCount,
              commentCount: data.commentCount,
              mentoringActive: data.hasActiveMentoring,
              isBoosted: data.isBoosted,
              onLike: onLike ?? () {},
              onComment: onComment ?? () => _openOriginal(context),
              onBookmark: onBookmark ?? () {},
              onMentoring: onMentoring ?? () => _openOriginal(context),
              onBoost: onBoost ?? () => _openOriginal(context),
            ),
          ],
        ),
      ),
    );

    if (!horizontal) return card;
    return SizedBox(width: width ?? 300, child: card);
  }
}
