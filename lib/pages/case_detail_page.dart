import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/community_case_item.dart';
import '../models/customer_chart.dart';
import '../models/customer_review.dart';
import '../services/instagram_quick_post.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/case_persona.dart';
import '../utils/sori_nav.dart';
import '../widgets/author_content_actions_sheet.dart';
import '../widgets/before_after_slider.dart';
import '../widgets/case_review_inline.dart';
import '../widgets/fan_sponsor_credits.dart';
import '../widgets/official_badge.dart';
import '../widgets/premium_mentoring_detail_section.dart';
import '../widgets/sori_logo.dart';
import '../routing/sori_router.dart';
import 'package:go_router/go_router.dart';

/// 인스타그램 스타일 풀스크린 B/A 케이스 상세.
class CaseDetailPage extends StatefulWidget {
  const CaseDetailPage({
    super.key,
    required this.item,
    this.review,
    this.currentUserId,
    this.liked = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.bookmarked = false,
    this.onLike,
    this.onComment,
    this.onBookmark,
    this.onShopProfile,
    this.onBookingCta,
    this.onOpenCommunitySeminar,
    this.focusMentoringSection = false,
  });

  final CommunityCaseItem item;
  final CustomerReview? review;
  final String? currentUserId;
  final bool liked;
  final int likeCount;
  final int commentCount;
  final bool bookmarked;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onBookmark;
  final VoidCallback? onShopProfile;
  final VoidCallback? onBookingCta;

  /// ⋯ 메뉴 — Community 세미나 딥링크.
  final VoidCallback? onOpenCommunitySeminar;

  /// Feed chip tap — scroll to Premium Mentoring unlock block.
  final bool focusMentoringSection;

  static String imageHeroTag(String chartId) => 'case_image_$chartId';

  static Future<void> push(
    BuildContext context, {
    required CaseDetailPage page,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    // PC: modal dialog — no fullscreen route that stretches mobile layout.
    if (width >= 800) {
      return showGeneralDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        transitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (ctx, animation, secondaryAnimation) {
          final maxH = MediaQuery.sizeOf(ctx).height * 0.92;
          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 920,
                  maxHeight: maxH,
                ),
                child: Material(
                  color: SoriTokens.background,
                  elevation: 12,
                  shadowColor: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: page,
                ),
              ),
            ),
          );
        },
        transitionBuilder: (ctx, animation, secondary, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      );
    }
    return pushRootPage<void>(context, page);
  }

  @override
  State<CaseDetailPage> createState() => _CaseDetailPageState();
}

class _CaseDetailPageState extends State<CaseDetailPage> {
  final _shot = ScreenshotController();
  final _scrollController = ScrollController();
  final _mentoringSectionKey = GlobalKey();
  bool _sharing = false;
  late bool _liked;
  late int _likeCount;

  SoriStore get _store => SoriStore.instance;

  CommunityCaseItem get item => widget.item;
  CustomerReview? get review => widget.review;

  CustomerChart get _chart => item.chart.copyWith(
        feedAge: item.customerAge ?? item.chart.feedAge,
        feedGenderLabel:
            item.customerGenderLabel ?? item.chart.feedGenderLabel,
      );

  bool get _isAuthor => InstagramQuickPost.canShare(
        currentUserId: widget.currentUserId,
        authorId: item.authorId ?? item.chart.authorId,
      );

  @override
  void initState() {
    super.initState();
    _liked = widget.liked;
    _likeCount = widget.likeCount;
    if (widget.focusMentoringSection) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToMentoring());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToMentoring() {
    final ctx = _mentoringSectionKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOut,
      alignment: 0.08,
    );
  }

  Widget _baSlider(CustomerChart chart, {double? maxHeight}) {
    final screenH = MediaQuery.sizeOf(context).height;
    return BeforeAfterSlider(
      aspectRatio: 4 / 3,
      maxHeight: maxHeight ?? screenH * 0.55,
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

  void _toggleLike() {
    setState(() {
      if (_liked) {
        _liked = false;
        _likeCount = (_likeCount - 1).clamp(0, 9999);
      } else {
        _liked = true;
        _likeCount += 1;
      }
    });
    widget.onLike?.call();
  }

  void _toggleBookmark() {
    widget.onBookmark?.call();
  }

  Future<void> _openBooking() async {
    if (widget.onBookingCta != null) {
      widget.onBookingCta!();
      return;
    }
    final url = item.shop.naverBookingOrPlaceUrl;
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openMore() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: SoriTokens.background,
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
                  widget.onShopProfile?.call();
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
                    _openBooking();
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

  Future<void> _openAuthorMenu() async {
    final action = await showAuthorContentActionsSheet(
      context,
      showDraft: false,
      showEdit: true,
      showDelete: true,
      deleteLabel: '피드에서 내리기',
    );
    if (!mounted || action == null) return;
    switch (action) {
      case AuthorContentAction.draft:
        break;
      case AuthorContentAction.edit:
        context.push(
          '${AppPaths.chartCreate}?chartId=${Uri.encodeComponent(item.chart.id)}',
        );
      case AuthorContentAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('피드에서 내리기'),
            content: const Text(
              '이 B/A 게시물을 커뮤니티 피드에서 비공개로 전환할까요?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  '내리기',
                  style: TextStyle(color: SoriTokens.systemRed),
                ),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        final ok = _store.setManagementCaseShared(item.chart.id, false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok ? '피드에서 내렸습니다.' : '피드 비공개에 실패했습니다.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (ok) {
          await _store.refreshCommunityHotCases();
          if (mounted) Navigator.pop(context);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = item.shop;
    final chart = _chart;
    final care = chart.serviceMenuLabel;
    final meta = CasePersona.feedLine(
      chart: chart,
      age: item.customerAge ?? chart.age,
      genderLabel: item.customerGenderLabel ?? chart.gender,
    );
    final device = chart.deviceInfo?.trim() ?? '';
    final tags = item.displayCareTags;
    final hasBooking = shop.naverBookingOrPlaceUrl.isNotEmpty;
    final reviewText = review?.displayText.trim() ?? '';
    final hasReview = reviewText.isNotEmpty;
    final avatar = shop.profileImageUrl?.trim() ?? '';
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        backgroundColor: SoriTokens.surface,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: SoriTokens.textPrimary),
        title: GestureDetector(
          onTap: widget.onShopProfile,
          child: Row(
            children: [
              CircleAvatar(
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
              const SizedBox(width: 10),
              Expanded(
                child: ShopNameWithOfficialBadge(
                  name: shop.name.trim().isEmpty ? 'SORI' : shop.name,
                  isOfficial: shop.displayIsOfficial,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (_isAuthor)
            IconButton(
              onPressed: _sharing ? null : () => _quickPost(chart),
              tooltip: '인스타그램 퀵 게시',
              icon: Icon(
                _sharing
                    ? Icons.hourglass_top_rounded
                    : Icons.send_outlined,
                size: 22,
              ),
            ),
          IconButton(
            onPressed: _isAuthor ? _openAuthorMenu : _openMore,
            icon: Icon(_isAuthor ? Icons.more_vert_rounded : Icons.more_horiz),
          ),
        ],
      ),
      body: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.only(bottom: 24 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Hero(
                  tag: CaseDetailPage.imageHeroTag(chart.id),
                  child: Material(
                    color: SoriTokens.primarySoft,
                    child: Screenshot(
                      controller: _shot,
                      child: _baSlider(chart),
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
                            onPressed: _toggleLike,
                            icon: Icon(
                              _liked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 26,
                              color: _liked
                                  ? SoriTokens.systemRed
                                  : SoriTokens.textPrimary,
                            ),
                          ),
                          Text(
                            '$_likeCount',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          IconButton(
                            onPressed: widget.onComment,
                            icon: Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 24,
                              color: SoriTokens.textPrimary,
                            ),
                          ),
                          Text(
                            '${widget.commentCount}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: _toggleBookmark,
                        icon: Icon(
                          widget.bookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 26,
                          color: widget.bookmarked
                              ? SoriTokens.primary
                              : SoriTokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: hasBooking
                      ? OutlinedButton.icon(
                          onPressed: _openBooking,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: SoriTokens.primary,
                            backgroundColor: SoriTokens.primarySoft,
                            side: const BorderSide(
                              color: SoriTokens.primary,
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            minimumSize: const Size(double.infinity, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(
                            Icons.calendar_month_outlined,
                            size: 18,
                          ),
                          label: const Text(
                            '네이버 예약',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: widget.onShopProfile,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: SoriTokens.primary,
                            backgroundColor: SoriTokens.primarySoft,
                            side: const BorderSide(
                              color: SoriTokens.primary,
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            minimumSize: const Size(double.infinity, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.storefront_outlined, size: 18),
                          label: const Text(
                            '샵 보기',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                ),
                PremiumMentoringDetailSection(
                  store: _store,
                  chartId: chart.id,
                  caseOwnerShopId: item.shop.id,
                  sectionKey: _mentoringSectionKey,
                  initialMeta: item.mentoring,
                  onReady: widget.focusMentoringSection
                      ? _scrollToMentoring
                      : null,
                ),
                if (item.isFanBoosted)
                  FanBoostCreditStrip(
                    supporters: item.effectiveFanSupporters,
                    onTap: () => showFanSupportersSheet(
                      context,
                      supporters: item.effectiveFanSupporters,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Text(
                    care,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      height: 1.25,
                      color: Colors.black,
                    ),
                  ),
                ),
                if (meta.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      meta,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ),
                if (device.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Text(
                      '$device 사용',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: SoriTokens.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ),
                if (tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: tags.map((raw) {
                        final label = raw.trim().startsWith('#')
                            ? raw.trim()
                            : '#${raw.trim()}';
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: SoriTokens.primarySoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: SoriTokens.primary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: hasReview
                      ? CaseReviewInlineBlock(
                          review: review!,
                          compact: false,
                          previewMaxLines: 99,
                          anonymizeNames: true,
                        )
                      : Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: SoriTokens.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: SoriTokens.outlinePurple),
                          ),
                          child: Text(
                            '후기 미작성',
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                              color: SoriTokens.textSecondary,
                            ),
                          ),
                        ),
                ),
              ],
            ),
      ),
    );
  }
}
