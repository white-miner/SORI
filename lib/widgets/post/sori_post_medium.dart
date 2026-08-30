import 'package:flutter/material.dart';

import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../utils/post_navigation.dart';
import '../../widgets/sori_glass_surface.dart';
import 'post_action_row.dart';
import 'post_ai_content.dart';
import 'post_header.dart';
import 'post_media_section.dart';
import 'post_read_more_link.dart';
import 'post_view_data.dart';

/// Tier B — home central feed (visual-first, 2-line caption).
class SoriPostMedium extends StatelessWidget {
  const SoriPostMedium({
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
    this.onShopProfile,
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
  final VoidCallback? onShopProfile;

  void _openOriginal(BuildContext context) {
    openPostOriginal(context, data: data, store: store);
  }

  @override
  Widget build(BuildContext context) {
    return SoriGlassSurface(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PostHeader(
            data: data,
            onAvatarTap: onShopProfile,
            onMore: onShopProfile,
          ),
          if (data.bodyText.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: _MediumCaption(
                text: data.bodyText,
                onReadMore: () => _openOriginal(context),
              ),
            ),
          PostAiContent(data: data),
          PostMediaSection(
            slides: data.mediaSlides,
            heroTag: data.heroTag,
            onOpenDetail: () => _openOriginal(context),
          ),
          PostActionRow(
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
    );
  }
}

class _MediumCaption extends StatelessWidget {
  const _MediumCaption({required this.text, required this.onReadMore});

  final String text;
  final VoidCallback onReadMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text.trim(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.35,
            color: SoriTokens.textPrimary,
          ),
        ),
        PostReadMoreLink(onTap: onReadMore),
      ],
    );
  }
}
