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
import 'mentoring_request_sheet.dart';
import 'official_badge.dart';

/// í íě íźë ěš´ë â ëŞ¨ëí ëĽęˇź ěš´ë.
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
    this.onOpenMentoring,
    this.onMentoringRequest,
    this.showMentoringRequest = false,
    this.currentUserId,
    this.review,
  });

  final CommunityCaseItem item;
  final CustomerReview? review;

  /// ëĄęˇ¸ě¸í ě ě  ID (`SessionUser.id` / `auth.users.id`).
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

  /// âŻ ëŠë´ â Community ě¸ëŻ¸ë ëĽë§íŹ (1ę¸ CTA ěë).
  final VoidCallback? onOpenCommunitySeminar;

  /// ěěąě ě ěŠ â ě°ëŚŹ ě§ě­ ë¸ěś ëśě¤í° ęľŹë§¤.
  final VoidCallback? onBoostPurchase;

  /// ęł ę°(íŹ) ě ěŠ â Fan-Boost.
  final VoidCallback? onFanBoostPurchase;

  final VoidCallback? onOpenMentoring;
  final VoidCallback? onMentoringRequest;
  final bool showMentoringRequest;

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
          content: Text('ę˛ěëŹź ë´ěŠě´ ëłľěŹëěěľëë¤. ě¸ě¤íęˇ¸ë¨ě ëśěŹëŁę¸° íě¸ě!'),
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
        SnackBar(content: Text('ęłľě ě ě¤í¨íěľëë¤. ë¤ě ěëí´ ěŁźě¸ě. ($e)')),
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
    final mentoring = item.mentoring;
    final hasActiveMentoring = item.hasActiveMentoring && mentoring != null;
    final mentoringPrice = mentoring?.priceEcho ?? 0;

    Widget? carouselTrailing;
    if (hasActiveMentoring || item.isBoosted) {
      carouselTrailing = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasActiveMentoring)
            PremiumMentoringFeedChip(
              priceEcho: mentoringPrice,
              compact: true,
              onTap: widget.onOpenMentoring,
            ),
          if (hasActiveMentoring && item.isBoosted) const SizedBox(height: 6),
          if (item.isBoosted)
            Container(
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
                        ? 'Special Supporter'
                        : '${item.specialSupporterName.trim()} · Special')
                    : item.isFanBoosted
                        ? (item.fanDisplayName.trim().isEmpty
                            ? 'Supporter'
                            : '${item.fanDisplayName.trim()} · Supporter')
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
            ),
        ],
      );
    }

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
                                        ? 'íëí°ë'
                                        : 'ęł¨ë')
                                    : item.isFanBoosted
                                        ? (item.fanDisplayName.trim().isEmpty
                                            ? 'íě'
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
                          ].join(' Âˇ '),
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
              topTrailing: carouselTrailing,
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
                        tooltip: 'ě¸ě¤íęˇ¸ë¨ íľ ę˛ě',
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
                    if (hasActiveMentoring)
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: PremiumMentoringFeedChip(
                          priceEcho: mentoringPrice,
                          onTap: widget.onOpenMentoring,
                        ),
                      ),
                    if (widget.showMentoringRequest &&
                        widget.onMentoringRequest != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: TextButton(
                          onPressed: widget.onMentoringRequest,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            foregroundColor: const Color(0xFF4338CA),
                          ),
                          child: const Text(
                            'Mentoring Request',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
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
                  tooltip: widget.bookmarked ? 'ëł´ę´í¨ěě ě ęą°' : 'ëł´ę´í¨ě ě ěĽ',
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
                    'íę¸° ëŻ¸ěěą',
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

  /// ěěąě â ěľ AD / íŹ â Fan-Boost. ěěźëŠ´ null (ěě´ě˝ ě¨ęš).
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
                title: const Text('ěľ íëĄí ëł´ę¸°'),
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
                  title: const Text('ë¤ě´ë˛ ěě˝'),
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
                  title: const Text('ë´ ěě ěźě´ě¤ ëě°ę¸°'),
                  subtitle: const Text('ě°ëŚŹ ě§ě­ íźë ěŹëĄŻ íźíŠ ë¸ěś'),
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
                  title: const Text('ěěĽë ę˛ěëŹź ěěíę¸°'),
                  subtitle: const Text('ëśě¤í° íě Âˇ ëë¤ě ęłľę°'),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onFanBoostPurchase!();
                  },
                ),
              if (widget.onOpenCommunitySeminar != null)
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('Communityěě ě¸ëŻ¸ë ëł´ę¸°'),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onOpenCommunitySeminar!();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('ëŤę¸°'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// YouTube-style minimal booking chip â wrap-content capsule beside hashtags.
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
                'ěě˝',
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
