import 'package:flutter/material.dart';

import '../models/community_case_item.dart';
import '../models/customer_review.dart';
import '../theme/sori_tokens.dart';
import 'before_after_slider.dart';
import 'case_review_inline.dart';
import 'sori_logo.dart';

/// 홈 탐색 피드 카드 — 인스타그램형 Edge-to-Edge 블록.
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
    this.showDivider = true,
    this.review,
  });

  final CommunityCaseItem item;
  final CustomerReview? review;
  final bool liked;
  final int likeCount;
  final int commentCount;
  final bool bookmarked;
  final bool showSeminarRequest;
  final bool showDivider;
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
    final chart = item.chart.copyWith(
      feedAge: item.customerAge ?? item.chart.feedAge,
      feedGenderLabel:
          item.customerGenderLabel ?? item.chart.feedGenderLabel,
    );
    final care = chart.serviceMenuLabel;
    final meta = chart.metadataSummaryLine;
    final reviewText = review?.displayText.trim() ?? '';
    final hasReview = reviewText.isNotEmpty;
    final avatar = shop.profileImageUrl?.trim() ?? '';
    final tags = item.displayCareTags;
    final hasBooking = shop.naverBookingOrPlaceUrl.isNotEmpty;
    final relative = chart.relativeTimeLabel;

    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
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
                      color: Colors.black,
                    ),
                  ),
                ),
                if (relative.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      relative,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () => _openMore(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  icon: Icon(
                    Icons.more_horiz,
                    color: Colors.grey[800],
                    size: 22,
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
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: Text(
              care,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                height: 1.25,
                color: Colors.black,
              ),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                  color: Colors.grey[600],
                ),
              ),
            ),
          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tags.take(8).map((raw) {
                  final label = raw.trim().startsWith('#')
                      ? raw.trim()
                      : '#${raw.trim()}';
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6D28D9),
                        height: 1.2,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          if (hasBooking)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onBookingCta,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF03C75A),
                    backgroundColor: const Color(0xFFE8F8EE),
                    side: const BorderSide(color: Color(0xFF03C75A), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    minimumSize: const Size(double.infinity, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_month_outlined, size: 16),
                  label: const Text(
                    '네이버 예약',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
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
          if (showDivider)
            Divider(height: 1, thickness: 1, color: Colors.grey[200]),
        ],
      ),
    );
  }

  void _openMore(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('샵 프로필 보기'),
                onTap: () {
                  Navigator.pop(ctx);
                  onShopProfile();
                },
              ),
              if (item.shop.naverBookingOrPlaceUrl.isNotEmpty)
                ListTile(
                  leading: const Icon(
                    Icons.calendar_month_outlined,
                    color: Color(0xFF03C75A),
                  ),
                  title: const Text('네이버 예약'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onBookingCta();
                  },
                ),
              if (showSeminarRequest && onSeminarRequest != null)
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('세미나 요청'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onSeminarRequest!();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('닫기'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }
}
