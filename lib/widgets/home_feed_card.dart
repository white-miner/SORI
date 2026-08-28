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
import 'fan_boost_aurora_avatar.dart';
import 'fan_sponsor_credits.dart';
import 'feed_expandable_caption.dart';
import 'feed_media_carousel.dart';
import 'official_badge.dart';

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
    this.onBoostPurchase,
    this.onFanBoostPurchase,
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

  /// 작성자 전용 — 우리 지역 노출 부스터 구매.
  final VoidCallback? onBoostPurchase;

  /// 고객(팬) 전용 — Fan-Boost.
  final VoidCallback? onFanBoostPurchase;

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
        tone: SoriTokens.textSecondary,
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
    final avatar = item.displayAuthorAvatarUrl;
    final nickname = item.displayAuthorNickname;
    final shopName = item.displayShopAffiliation;
    final tags = item.displayCareTags;
    final hasBooking = shop.naverBookingOrPlaceUrl.isNotEmpty;
    final relative = chart.relativeTimeLabel;
    final canShare = _isAuthor;
    final bodyCaption = [
      care,
      if (meta.isNotEmpty) meta,
      if (chart.treatmentSummary.trim().isNotEmpty) chart.treatmentSummary.trim(),
    ].where((e) => e.trim().isNotEmpty).join('\n');
    final slides = feedSlidesForCase(
      beforeUrl: chart.beforeImageUrl,
      afterUrl: chart.afterImageUrl,
    );

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: widget.onShopProfile,
                  child: FanBoostAuroraAvatar(
                    imageUrl: avatar,
                    isBoostActive: item.isBoosted,
                    isFanBoost: item.isFanBoosted,
                    premiumTier: item.premiumTier,
                    radius: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: GestureDetector(
                              onTap: widget.onShopProfile,
                              child: Text(
                                nickname,
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
                          ),
                          if (shop.displayIsOfficial) ...[
                            const SizedBox(width: 6),
                            const OfficialBadge(compact: true),
                          ],
                          if (item.isBoosted) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: item.hasPremiumOverlay
                                    ? (item.isSpecialPlatinum
                                        ? const Color(0x22E2E8F0)
                                        : const Color(0x22FBBF24))
                                    : item.isFanBoosted
                                        ? const Color(0x22F472B6)
                                        : const Color(0x22FBBF24),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: item.hasPremiumOverlay
                                      ? (item.isSpecialPlatinum
                                          ? const Color(0x66E2E8F0)
                                          : const Color(0x66FBBF24))
                                      : item.isFanBoosted
                                          ? const Color(0x66F472B6)
                                          : const Color(0x66FBBF24),
                                ),
                              ),
                              child: Text(
                                item.hasPremiumOverlay
                                    ? (item.isSpecialPlatinum
                                        ? '플래티넘'
                                        : '골드')
                                    : item.isFanBoosted
                                        ? (item.fanDisplayName.trim().isEmpty
                                            ? '후원'
                                            : item.fanDisplayName.trim())
                                        : 'AD',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                  color: item.isFanBoosted
                                      ? SoriTokens.textSecondary
                                      : SoriTokens.warningText,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: widget.onShopProfile,
                        child: Text(
                          [
                            shopName,
                            if (relative.isNotEmpty) relative,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                        color: SoriTokens.textTertiary,
                      ),
                        ),
                      ),
                    ],
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
          if (bodyCaption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: FeedExpandableCaption(
                text: bodyCaption,
                maxLines: 2,
              ),
            ),
          if (slides.isNotEmpty)
            FeedMediaCarousel(
              slides: slides,
              heroTag: CaseDetailPage.imageHeroTag(chart.id),
              onTap: widget.onOpenDetail,
              onDoubleTap: widget.onOpenDetail,
              topTrailing: item.isBoosted
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: item.isFanBoosted
                              ? const Color(0x99F472B6)
                              : const Color(0x99FBBF24),
                        ),
                      ),
                      child: Text(
                        item.hasPremiumOverlay
                            ? (item.specialSupporterName.trim().isEmpty
                                ? '스페셜 후원'
                                : '${item.specialSupporterName.trim()}님 스페셜 후원')
                            : item.isFanBoosted
                                ? (item.fanDisplayName.trim().isEmpty
                                    ? '후원'
                                    : '${item.fanDisplayName.trim()}님 후원')
                                : 'Sponsored',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: item.isFanBoosted
                              ? SoriTokens.textSecondary
                              : SoriTokens.warningText,
                          letterSpacing: 0.2,
                        ),
                      ),
                    )
                  : null,
            ),
          if (item.isFanBoosted || item.hasPremiumOverlay)
            FanBoostCreditStrip(
              supporters: item.effectiveFanSupporters,
              premiumTier: item.premiumTier,
              specialName: item.specialSupporterName,
              onTap: () => showFanSupportersSheet(
                context,
                supporters: item.effectiveFanSupporters,
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
                            ? SoriTokens.systemRed
                            : SoriTokens.textTertiary,
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
                        color: SoriTokens.textTertiary,
                      ),
                    ),
                    Text(
                      '${widget.commentCount}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: SoriTokens.textSecondary,
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
                          color: SoriTokens.textTertiary,
                        ),
                      ),
                    if (_boostTrigger != null)
                      IconButton(
                        onPressed: _boostTrigger,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        visualDensity: VisualDensity.compact,
                        tooltip: _isAuthor
                            ? '내 임상 케이스 띄우기'
                            : '원장님 게시물 응원하기',
                        icon: Icon(
                          Icons.local_fire_department_rounded,
                          size: 24,
                          color: item.isBoosted
                              ? SoriTokens.textSecondary
                              : SoriTokens.textSecondary,
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
                        ? SoriTokens.textPrimary
                        : SoriTokens.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (tags.isNotEmpty || hasBooking)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: tags.isEmpty
                        ? const SizedBox.shrink()
                        : Wrap(
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
                                  color: SoriTokens.surfaceOverlay,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: SoriTokens.textSecondary,
                                    height: 1.2,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  if (hasBooking) ...[
                    if (tags.isNotEmpty) const SizedBox(width: 8),
                    _ReservationChip(onTap: widget.onBookingCta),
                  ],
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: hasReview
                ? CaseReviewInlineBlock(
                    review: review!,
                    compact: true,
                    previewMaxLines: 2,
                    anonymizeNames: true,
                    expandInline: true,
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
    );
  }

  /// 작성자 → 샵 AD / 팬 → Fan-Boost. 없으면 null (아이콘 숨김).
  VoidCallback? get _boostTrigger {
    if (widget.onBoostPurchase != null &&
        item.isAuthoredBy(widget.currentUserId)) {
      return widget.onBoostPurchase;
    }
    if (widget.onFanBoostPurchase != null &&
        !item.isAuthoredBy(widget.currentUserId)) {
      return widget.onFanBoostPurchase;
    }
    return null;
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
                    color: SoriTokens.primary,
                  ),
                  title: const Text('네이버 예약'),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onBookingCta();
                  },
                ),
              if (widget.onBoostPurchase != null &&
                  item.isAuthoredBy(widget.currentUserId))
                ListTile(
                  leading: const Icon(
                    Icons.local_fire_department_rounded,
                    color: SoriTokens.textSecondary,
                  ),
                  title: const Text('내 임상 케이스 띄우기'),
                  subtitle: const Text('우리 지역 피드 슬롯 혼합 노출'),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onBoostPurchase!();
                  },
                ),
              if (widget.onFanBoostPurchase != null &&
                  !item.isAuthoredBy(widget.currentUserId))
                ListTile(
                  leading: const Icon(
                    Icons.local_fire_department_rounded,
                    color: SoriTokens.textSecondary,
                  ),
                  title: const Text('원장님 게시물 응원하기'),
                  subtitle: const Text('부스터 후원 · 닉네임 공개'),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onFanBoostPurchase!();
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

/// YouTube-style minimal booking chip — wrap-content capsule beside hashtags.
class _ReservationChip extends StatelessWidget {
  const _ReservationChip({required this.onTap});

  final VoidCallback onTap;

  static const _bg = Color(0xFFF1F1F1);
  static const _fg = Color(0xFF111111);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bg,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month_outlined, size: 12, color: _fg),
              SizedBox(width: 4),
              Text(
                '예약',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _fg,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
