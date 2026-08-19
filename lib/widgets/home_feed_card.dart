import 'package:flutter/material.dart';

import '../models/community_case_item.dart';
import '../models/customer_review.dart';
import '../theme/sori_tokens.dart';
import 'before_after_slider.dart';
import 'case_review_inline.dart';
import 'shop_tier_badge_chip.dart';
import 'sori_logo.dart';

/// 홈 탐색 피드 카드 — Edge-to-Edge 1:1 B/A + 페르소나 헤더.
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
    final care = chart.careName.trim().isNotEmpty
        ? chart.careName.trim()
        : '관리 케이스';
    final device = chart.deviceInfo?.trim() ?? '';
    final hasReview =
        review != null && review!.displayText.trim().isNotEmpty;
    final avatar = shop.profileImageUrl?.trim() ?? '';
    final tags = item.displayCareTags;
    final hasBooking = shop.naverBookingOrPlaceUrl.isNotEmpty;
    final persona = item.personaLine;

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: onShopProfile,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: SoriTokens.primarySoft,
                    backgroundImage:
                        avatar.isNotEmpty && !avatar.startsWith('data:')
                            ? NetworkImage(avatar)
                            : null,
                    child: avatar.isEmpty || avatar.startsWith('data:')
                        ? const Padding(
                            padding: EdgeInsets.all(6),
                            child: SoriLogo(width: 22, height: 22),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name.trim().isEmpty ? 'SORI' : shop.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          height: 1.2,
                        ),
                      ),
                      if (persona.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _PersonaBadge(text: persona),
                      ],
                    ],
                  ),
                ),
                if (hasReview) const VerifiedReviewBadge(small: true),
                if (shop.tierBadge.isVisible) ...[
                  const SizedBox(width: 6),
                  ShopTierBadgeChip(badge: shop.tierBadge, compact: true),
                ],
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
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: onLike,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        size: 26,
                        color: liked
                            ? const Color(0xFFE53935)
                            : Colors.grey[800],
                      ),
                    ),
                    Text(
                      '$likeCount',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    IconButton(
                      onPressed: onComment,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 24,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      '$commentCount',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: onBookmark,
                  visualDensity: VisualDensity.compact,
                  tooltip: bookmarked ? '보관함에서 제거' : '보관함에 저장',
                  icon: Icon(
                    bookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 26,
                    color: bookmarked
                        ? SoriTokens.primary
                        : Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: care,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            height: 1.35,
                            color: SoriTokens.textPrimary,
                          ),
                        ),
                        if (device.isNotEmpty)
                          TextSpan(
                            text: '  ·  $device 사용',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              height: 1.35,
                              color: Colors.grey.shade700,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasBooking)
                  TextButton(
                    onPressed: onBookingCta,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF03C75A),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      '네이버 예약',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  )
                else
                  TextButton(
                    onPressed: onShopProfile,
                    style: TextButton.styleFrom(
                      foregroundColor: SoriTokens.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      '샵 프로필',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
              ],
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
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.school_outlined, size: 16),
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
                spacing: 6,
                runSpacing: 4,
                children: tags.take(8).map((raw) {
                  final label = raw.trim().startsWith('#')
                      ? raw.trim()
                      : '#${raw.trim()}';
                  return InputChip(
                    label: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                        height: 1.1,
                      ),
                    ),
                    onPressed: () {},
                    visualDensity: const VisualDensity(
                      horizontal: -4,
                      vertical: -4,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    backgroundColor: Colors.transparent,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99),
                    ),
                  );
                }).toList(),
              ),
            ),
          if (hasReview)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: CaseReviewInlineBlock(
                review: review!,
                compact: true,
                previewMaxLines: 3,
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _PersonaBadge extends StatelessWidget {
  const _PersonaBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: SoriTokens.primarySoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1.2,
          color: SoriTokens.primary,
        ),
      ),
    );
  }
}
