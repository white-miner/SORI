import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';

import '../models/community_case_item.dart';
import '../models/customer_chart.dart';
import '../models/customer_review.dart';
import '../services/instagram_quick_post.dart';
import '../theme/sori_tokens.dart';
import '../pages/case_detail_page.dart';
import '../utils/case_persona.dart';
import 'before_after_slider.dart';
import 'case_review_inline.dart';
import 'sori_logo.dart';

/// 홈 탐색 피드 카드 — 모듈형 둥근 카드.
class HomeFeedCard extends StatefulWidget {
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
    required this.onOpenDetail,
    required this.onBookingCta,
    required this.onShopProfile,
    this.onOpenCommunitySeminar,
    this.currentUserId,
    this.review,
  });

  final CommunityCaseItem item;
  final CustomerReview? review;

  /// 로그인한 유저 ID (`SessionUser.id` / `auth.users.id`).
  final String? currentUserId;
  final bool liked;
  final int likeCount;
  final int commentCount;
  final bool bookmarked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onBookmark;
  final VoidCallback onOpenDetail;
  final VoidCallback onBookingCta;
  final VoidCallback onShopProfile;

  /// ⋯ 메뉴 — Community 세미나 딥링크 (1급 CTA 아님).
  final VoidCallback? onOpenCommunitySeminar;

  @override
  State<HomeFeedCard> createState() => _HomeFeedCardState();
}

class _HomeFeedCardState extends State<HomeFeedCard> {
  final _shot = ScreenshotController();
  bool _sharing = false;

  CommunityCaseItem get item => widget.item;
  CustomerReview? get review => widget.review;

  bool get _isAuthor => InstagramQuickPost.canShare(
        currentUserId: widget.currentUserId,
        authorId: item.authorId ?? item.chart.authorId,
      );

  Widget _baSlider(CustomerChart chart, {double maxHeight = 380}) {
    return BeforeAfterSlider(
      aspectRatio: 4 / 3,
      maxHeight: maxHeight,
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
    );
  }

  Future<Uint8List?> _captureBa(CustomerChart chart) async {
    try {
      final onScreen = await _shot.capture(
        pixelRatio: MediaQuery.devicePixelRatioOf(context).clamp(2.0, 3.0),
        delay: const Duration(milliseconds: 16),
      );
      if (onScreen != null && onScreen.isNotEmpty) return onScreen;
    } catch (_) {}

    if (!mounted) return null;
    try {
      const size = Size(1080, 810);
      return await _shot.captureFromWidget(
        MediaQuery(
          data: const MediaQueryData(size: size, devicePixelRatio: 2),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Material(
              color: Colors.black,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: _baSlider(chart, maxHeight: size.height),
              ),
            ),
          ),
        ),
        context: context,
        delay: const Duration(milliseconds: 180),
        pixelRatio: 2,
        targetSize: size,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _quickPost(CustomerChart chart) async {
    if (!_isAuthor || _sharing) return;
    setState(() => _sharing = true);
    try {
      final caption = InstagramQuickPost.buildCaption(
        item: item,
        chart: chart,
        review: review,
      );
      await InstagramQuickPost.copyCaption(caption);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('게시물 내용이 복사되었습니다. 인스타그램에 붙여넣기 하세요!'),
        ),
      );

      final bytes = await _captureBa(chart);
      if (bytes != null && bytes.isNotEmpty) {
        await InstagramQuickPost.shareCapturedImage(
          bytes,
          fileName: 'sori-ba-${chart.id}.png',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('공유에 실패했습니다. 다시 시도해 주세요. ($e)')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = item.shop;
    final chart = item.chart.copyWith(
      feedAge: item.customerAge ?? item.chart.feedAge,
      feedGenderLabel:
          item.customerGenderLabel ?? item.chart.feedGenderLabel,
    );
    final care = chart.serviceMenuLabel;
    final meta = CasePersona.feedLine(
      chart: chart,
      age: item.customerAge ?? chart.age,
      genderLabel: item.customerGenderLabel ?? chart.gender,
    );
    final reviewText = review?.displayText.trim() ?? '';
    final hasReview = reviewText.isNotEmpty;
    final avatar = shop.profileImageUrl?.trim() ?? '';
    final tags = item.displayCareTags;
    final hasBooking = shop.naverBookingOrPlaceUrl.isNotEmpty;
    final relative = chart.relativeTimeLabel;
    final canShare = _isAuthor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: SoriTokens.card(radius: 20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onShopProfile,
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
                      color: SoriTokens.textPrimary,
                    ),
                  ),
                ),
                if (relative.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      relative,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: _openMore,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  icon: const Icon(
                    Icons.more_horiz,
                    color: SoriTokens.textSecondary,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Hero(
                tag: CaseDetailPage.imageHeroTag(chart.id),
                child: Material(
                  color: const Color(0xFF111113),
                  child: Screenshot(
                    controller: _shot,
                    child: GestureDetector(
                      onDoubleTap: widget.onOpenDetail,
                      behavior: HitTestBehavior.deferToChild,
                      child: _baSlider(chart),
                    ),
                  ),
                ),
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
                      onPressed: widget.onLike,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        widget.liked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 24,
                        color: widget.liked
                            ? const Color(0xFFE53935)
                            : SoriTokens.textSecondary,
                      ),
                    ),
                    Text(
                      '${widget.likeCount}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: SoriTokens.textPrimary,
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onComment,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 22,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                    Text(
                      '${widget.commentCount}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: SoriTokens.textPrimary,
                      ),
                    ),
                    if (canShare)
                      IconButton(
                        onPressed: _sharing ? null : () => _quickPost(chart),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        visualDensity: VisualDensity.compact,
                        tooltip: '인스타그램 퀵 게시',
                        icon: Icon(
                          _sharing
                              ? Icons.hourglass_top_rounded
                              : Icons.send_outlined,
                          size: 22,
                          color: SoriTokens.textSecondary,
                        ),
                      ),
                  ],
                ),
                IconButton(
                  onPressed: widget.onBookmark,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  visualDensity: VisualDensity.compact,
                  tooltip: widget.bookmarked ? '보관함에서 제거' : '보관함에 저장',
                  icon: Icon(
                    widget.bookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 24,
                    color: widget.bookmarked
                        ? SoriTokens.primary
                        : SoriTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: widget.onOpenDetail,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                color: SoriTokens.textPrimary,
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
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                  color: SoriTokens.textSecondary,
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
                      color: SoriTokens.primarySoft,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: SoriTokens.outlinePurple,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFC4B5FD),
                        height: 1.2,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: hasReview
                ? CaseReviewInlineBlock(
                    review: review!,
                    compact: true,
                    previewMaxLines: 3,
                    anonymizeNames: true,
                  )
                : const Text(
                    '후기 미작성',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      color: SoriTokens.textSecondary,
                      height: 1.2,
                    ),
                  ),
          ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: hasBooking
                ? _naverBookingButton()
                : OutlinedButton.icon(
                    onPressed: widget.onShopProfile,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC4B5FD),
                      side: BorderSide(
                        color: SoriTokens.primary.withValues(alpha: 0.45),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      minimumSize: const Size(double.infinity, 40),
                    ),
                    icon: const Icon(Icons.storefront_outlined, size: 16),
                    label: const Text(
                      '샵 보기',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _naverBookingButton() {
    return FilledButton.icon(
      onPressed: widget.onBookingCta,
      style: FilledButton.styleFrom(
        backgroundColor: SoriTokens.primary,
        foregroundColor: Colors.white,
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
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }

  void _openMore() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: SoriTokens.surface,
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
                  widget.onShopProfile();
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
                    widget.onBookingCta();
                  },
                ),
              if (widget.onOpenCommunitySeminar != null)
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('Community에서 세미나 보기'),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onOpenCommunitySeminar!();
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
