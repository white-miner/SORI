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

/// Tier A — high-density mini card (Community + SORI Spot).
class SoriPostMini extends StatelessWidget {
  /// Fixed viewport height for horizontal carousels — action row baseline lock.
  static const double carouselHeight = 200;

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

  /// Fixed-height horizontal carousel with baseline-locked action rows.
  static Widget horizontalStrip({
    required List<Widget> children,
    EdgeInsets padding = const EdgeInsets.fromLTRB(16, 0, 16, 0),
  }) {
    if (children.isEmpty) {
      return Padding(
        padding: padding,
        child: const Text(
          '인기글을 불러오는 중…',
          style: TextStyle(
            color: SoriTokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return SizedBox(
      height: carouselHeight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        clipBehavior: Clip.hardEdge,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              children[i],
            ],
          ],
        ),
      ),
    );
  }

  void _openOriginal(BuildContext context) {
    openPostOriginal(context, data: data, store: store);
  }

  @override
  Widget build(BuildContext context) {
    final isCarousel = horizontal;
    final card = SoriGlassSurface(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openOriginal(context),
          child: isCarousel ? _buildCarouselColumn(context) : _buildWrapColumn(context),
        ),
      ),
    );

    if (!isCarousel) return card;
    return SizedBox(
      width: width ?? 300,
      height: carouselHeight,
      child: card,
    );
  }

  Widget _buildBodySection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.mediaSlides.isNotEmpty) ...[
            PostMiniThumbnail(slides: data.mediaSlides),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: PostTruncatedCaption(
              text: data.bodyText,
              maxLines: horizontal ? 2 : 3,
              onReadMore: () => _openOriginal(context),
              bodyStyle: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w400,
                color: data.bodyLocked
                    ? SoriTokens.textTertiary
                    : SoriTokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return PostActionRow(
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
      onMentoring: onMentoring ?? () {},
      onBoost: onBoost ?? () {},
      onMentoringLongPress: () => _openOriginal(context),
      onBoostLongPress: () => _openOriginal(context),
    );
  }

  Widget _buildWrapColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        PostHeader(data: data, dense: true),
        _buildBodySection(context),
        PostAiContent(
          data: data,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        ),
        _buildActionRow(context),
      ],
    );
  }

  Widget _buildCarouselColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PostHeader(data: data, dense: true),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBodySection(context),
              PostAiContent(
                data: data,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              ),
              const Spacer(),
            ],
          ),
        ),
        _buildActionRow(context),
      ],
    );
  }
}
