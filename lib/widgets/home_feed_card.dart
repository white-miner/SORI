import 'package:flutter/material.dart';

import '../models/community_case_item.dart';
import '../models/customer_review.dart';
import '../theme/sori_tokens.dart';
import 'before_after_slider.dart';
import 'case_review_inline.dart';
import 'sori_logo.dart';

/// 홈 탐색 피드 카드 — 헤더는 샵만, 본문에 차트 메타데이터.
class HomeFeedCard extends StatelessWidget {
  const HomeFeedCard({
    super.key,
    required this.item,
    required this.liked,
    required this.likeCount,
    required this.commentCount,
    required this.bookmarked,
    required this.onLike,
    required this.onComment,
    required this.onBookmark,
    required this.onOpenMedia,
    required this.onBookingCta,
    required this.onShopProfile,
    this.onOpenFullScreen,
    this.onSeminarRequest,
    this.showSeminarRequest = false,
    this.review,
  });

  final CommunityCaseItem item;
  final CustomerReview? review;
  final bool liked;
  final int likeCount;
  final int commentCount;
  final bool bookmarked;
  final bool showSeminarRequest;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onBookmark;
  final VoidCallback onOpenMedia;
  final VoidCallback? onOpenFullScreen;
  final VoidCallback? onSeminarRequest;
  final VoidCallback onBookingCta;
  final VoidCallback onShopProfile;

  @override
  Widget build(BuildContext context) {
    final shop = item.shop;
    final chart = item.chart;
    final care = chart.serviceMenuLabel;
    final meta = item.personaLine;
    final reviewText = review?.displayText.trim() ?? '';
    final hasReview = reviewText.isNotEmpty;
    final avatar = shop.profileImageUrl?.trim() ?? '';
    final tags = item.displayCareTags;
    final hasBooking = shop.naverBookingOrPlaceUrl.isNotEmpty;

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onShopProfile,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: SoriTokens.primarySoft,
                    backgroundImage:
                        avatar.isNotEmpty && !avatar.startsWith('data:')
                            ? NetworkImage(avatar)
                            : null,
                    child: avatar.isEmpty || avatar.startsWith('data:')
                        ? const Padding(
                            padding: EdgeInsets.all(5),
                            child: SoriLogo(width: 20, height: 20),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    shop.name.trim().isEmpty ? 'SORI' : shop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onOpenMedia,
            onLongPress: onOpenFullScreen,
            child: BeforeAfterSlider(
              aspectRatio: 1.0,
              maxHeight: 900,
              borderRadius: BorderRadius.zero,
              before: ChartImagePane(
                url: chart.beforeImageUrl,
                fallbackLabel: 'Before',
                tone: SoriTokens.primary,
              ),
              after: ChartImagePane(
                url: chart.afterImageUrl,
                fallbackLabel: 'After',
                tone: Colors.green.shade700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: onLike,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        size: 24,
                        color: liked
                            ? const Color(0xFFE53935)
                            : Colors.grey[800],
                      ),
                    ),
                    Text(
                      '$likeCount',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                    IconButton(
                      onPressed: onComment,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 22,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      '$commentCount',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: onBookmark,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  visualDensity: VisualDensity.compact,
                  tooltip: bookmarked ? '보관함에서 제거' : '보관함에 저장',
                  icon: Icon(
                    bookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 24,
                    color: bookmarked
                        ? SoriTokens.primary
                        : Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    care,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                      height: 1.25,
                      color: SoriTokens.textPrimary,
                    ),
                  ),
                ),
                if (hasBooking)
                  TextButton(
                    onPressed: onBookingCta,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF03C75A),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      '네이버 예약',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (meta.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: Text(
                meta,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          if (showSeminarRequest && onSeminarRequest != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onSeminarRequest,
                  style: TextButton.styleFrom(
                    foregroundColor: SoriTokens.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.school_outlined, size: 15),
                  label: const Text(
                    '세미나 요청',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 2,
                children: tags.take(8).map((raw) {
                  final label = raw.trim().startsWith('#')
                      ? raw.trim()
                      : '#${raw.trim()}';
                  return Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: SoriTokens.primary.withValues(alpha: 0.85),
                      height: 1.2,
                    ),
                  );
                }).toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: hasReview
                ? CaseReviewInlineBlock(
                    review: review!,
                    compact: true,
                    previewMaxLines: 3,
                  )
                : Text(
                    '후기 미작성',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade400,
                      height: 1.2,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
