import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ai_shop_report_mock.dart';
import '../models/customer_chart.dart';
import '../models/seminar_enrollment.dart';
import '../models/session_user.dart';
import '../models/shop.dart';
import '../models/shop_supporter_header.dart';
import '../services/director_stats.dart';
import '../services/sori_store.dart';
import '../theme/sori_tab_indicator.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_nav.dart';
import '../utils/storage_image_url.dart';
import '../widgets/debug_mode_chip.dart';
import '../widgets/my_ai_manager_tab_body.dart';
import '../widgets/my_seminar_tab_body.dart';
import '../widgets/my_tier_home_card.dart';
import '../widgets/seminar_review_modal.dart';
import '../widgets/shop_inline_info_tab.dart';
import '../widgets/shop_posts_thread_section.dart';
import '../widgets/shop_review_compose_sheet.dart';
import '../widgets/shop_supporter_header.dart';
import '../widgets/shop_tier_badge_chip.dart';
import '../widgets/shop_tier_progress_card.dart';
import '../widgets/sori_insta_picker.dart';
import '../widgets/sori_network_image.dart';
import 'ai_shop_report_page.dart';
import 'app_settings_page.dart';
import 'whisper_composer_sheet.dart';
import 'my_page_fandom_hub.dart';
import 'chart_customer_picker_sheet.dart';
import 'message_history_page.dart';
import 'post_first_creation_page.dart';
import 'seminar_class_open_page.dart';
import 'seminar_feedback_inbox_page.dart';

/// 원장 모드 마이페이지 — Instagram/Weverse형 시각 프로필 대시보드.
class DirectorMyPageView extends StatefulWidget {
  const DirectorMyPageView({
    super.key,
    required this.store,
    this.onSelectTab,
  });

  final SoriStore store;
  final ValueChanged<int>? onSelectTab;

  @override
  State<DirectorMyPageView> createState() => _DirectorMyPageViewState();
}

class _DirectorMyPageViewState extends State<DirectorMyPageView>
    with SingleTickerProviderStateMixin {
  SoriStore get store => widget.store;
  ValueChanged<int>? get onSelectTab => widget.onSelectTab;
  bool _avatarUploading = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    unawaited(store.refreshShopSupporterHeader());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? _topRequestedCaseId() {
    final insight = store.seminarEducationInsight;
    if (insight == null || insight.requestsByCase.isEmpty) return null;
    var bestId = '';
    var bestCount = -1;
    for (final e in insight.requestsByCase.entries) {
      if (e.value > bestCount) {
        bestCount = e.value;
        bestId = e.key;
      }
    }
    return bestId.isEmpty ? null : bestId;
  }

  CustomerChart? _chartById(String id) => store.findChartById(id);

  List<CustomerChart> get _baCases {
    final out = <CustomerChart>[];
    for (final chart in store.charts) {
      final b = chart.beforeImageUrl?.trim() ?? '';
      final a = chart.afterImageUrl?.trim() ?? '';
      if (b.isEmpty && a.isEmpty) continue;
      final shopId = store.shop.id;
      if (chart.shopId.isNotEmpty &&
          shopId.isNotEmpty &&
          chart.shopId != shopId) {
        continue;
      }
      out.add(chart);
    }
    out.sort((a, b) {
      final ad = a.visitCheckedAt ??
          a.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.visitCheckedAt ??
          b.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return out;
  }

  /// DB 샵 Bio 우선 — 홈케어 팁 더미는 사용하지 않음.
  String get _bio {
    final shop = store.shop;
    final bio = shop.bio.trim();
    if (bio.isNotEmpty) return bio;
    final hours = shop.operatingHours.trim();
    final parts = <String>[];
    if (hours.isNotEmpty) parts.add('영업 $hours');
    if (shop.address != null && shop.address!.trim().isNotEmpty) {
      parts.add(shop.address!.trim());
    }
    if (parts.isEmpty) {
      return '샵 소개말을 프로필 편집에서 등록해 주세요.';
    }
    return parts.join('\n');
  }

  Future<void> _pickAndUploadCover() async {
    if (_avatarUploading) return;
    final files = await openSoriInstaPicker(
      context,
      maxAssets: 1,
      title: '샵 간판',
    );
    if (files.isEmpty || !mounted) return;
    setState(() => _avatarUploading = true);
    try {
      final ok = await store.uploadShopCoverImage(files.first);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? '간판 이미지가 업데이트되었어요' : '업로드에 실패했어요',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ok ? SoriTokens.primary : SoriTokens.systemRed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('업로드 오류: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: SoriTokens.systemRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  Future<void> _openCreateSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _SoriQuickSheet(
          title: '새 게시물',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bolt_rounded, color: SoriTokens.primary),
                title: const Text(
                  '새 차트 작성',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: SoriTokens.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  '고객을 고르고 1초 간편 차트로 이동',
                  style: TextStyle(color: SoriTokens.textSecondary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  showChartCustomerPickerSheet(context, store: store);
                },
              ),
              const Divider(color: SoriTokens.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.campaign_outlined,
                    color: SoriTokens.primary),
                title: const Text(
                  '새 소식 작성',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: SoriTokens.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Home 탭 공지/프로모션',
                  style: TextStyle(color: SoriTokens.textSecondary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _openNoticeComposer();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openNoticeComposer() async {
    final titleCtrl = TextEditingController(text: '스페셜 프로모션 안내');
    final bodyCtrl = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final inset = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: _SoriQuickSheet(
            title: '새 소식 작성',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: '제목',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '내용',
                    hintText: '예: 8월 윤곽 리프팅 패키지 20% 혜택',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: SoriTokens.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    '게시하기',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (saved != true || !mounted) {
      titleCtrl.dispose();
      bodyCtrl.dispose();
      return;
    }
    final title = titleCtrl.text.trim();
    final body = bodyCtrl.text.trim();
    titleCtrl.dispose();
    bodyCtrl.dispose();
    final notice = body.isEmpty ? title : '$title\n$body';
    final prev = store.shop.bio.trim();
    final nextBio = prev.isEmpty ? notice : '$notice\n\n$prev';
    store.updateShopProfile(
      name: store.shop.name,
      naverPlaceUrl: store.shop.naverPlaceUrl,
      bio: nextBio,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('소식이 Home 탭에 반영되었어요'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: SoriTokens.primary,
      ),
    );
  }

  Future<void> _openAiReport() async {
    final report = AiShopReportMock.demo();
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _SoriQuickSheet(
          title: 'AI 샵 경영 리포트',
          child: _AiManagementSheetBody(
            report: report,
            onApply: () {
              Navigator.pop(ctx);
              pushRootPage<void>(
                context,
                AiShopReportPage(data: report),
              );
            },
            onDownload: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('8월 경영 리포트 요약이 준비되었어요'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: SoriTokens.primary,
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _openClass() {
    final topCase = _topRequestedCaseId();
    final chart = topCase == null ? null : _chartById(topCase);
    pushRootPage<void>(
      context,
      SeminarClassOpenPage(
        store: store,
        targetCaseId: topCase,
        initialTitle: chart?.careName ?? '',
      ),
    );
  }

  Future<void> _openTierSheet(Shop shop) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _SoriQuickSheet(
          title: '내 등급 · 티어 프로그레스',
          child: ShopTierProgressCard(shop: shop),
        );
      },
    );
  }

  Future<void> _openSeminarSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _SoriQuickSheet(
          title: '세미나 센터',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SeminarEducationInsightCard(
                loading: store.seminarEducationLoading,
                totalRequests:
                    store.seminarEducationInsight?.totalRequests ?? 0,
                soriCashBalance: store.shop.soriCashBalance,
                onOpenClass: () {
                  Navigator.pop(ctx);
                  _openClass();
                },
              ),
              const SizedBox(height: 8),
              Material(
                color: SoriTokens.surface,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: SoriTokens.outlinePurple),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SoriTokens.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '📊',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  title: const Text(
                    'AI 세미나 피드백 보관함',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: SoriTokens.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    store.seminarFeedbackReports.isEmpty
                        ? '세미나 후기 AI 인사이트를 모아보세요'
                        : (store.seminarFeedbackReportsLoading
                            ? '리포트 불러오는 중…'
                            : '완료 리포트 ${store.seminarFeedbackReports.length}건'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: SoriTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    SeminarFeedbackInboxPage.open(
                      context,
                      store: store,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              _MySeminarEnrollmentsSection(store: store),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final shop = store.shop;
    final session = store.session;
    final shopName =
        shop.name.trim().isEmpty ? 'Sori 에스테틱' : shop.name.trim();
    final cases = _baCases;
    final isOwner = session?.activeMode == UserRole.director;
    final coverUrl = (shop.coverImageUrl ?? '').trim();
    final regularCount = store.customers.isNotEmpty
        ? store.customers.length
        : shop.followerCount;

    final topInset = MediaQuery.paddingOf(context).top;
    final heroExpanded = 320 + topInset;
    final badgeCount = _notificationBadgeCount(session);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: SoriTokens.background,
      ),
      child: ColoredBox(
        color: SoriTokens.background,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              // expanded: 투명·풀블리드 / collapsed: #0A0A0C 솔리드(상태바 높이)
              // backgroundColor는 접힘 시 노출되며, 펼침 시에는 이미지가 덮음.
              SliverAppBar(
                expandedHeight: heroExpanded,
                pinned: true,
                stretch: true,
                elevation: 0,
                scrolledUnderElevation: 0,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                backgroundColor: const Color(0xFF0A0A0C),
                foregroundColor: Colors.white,
                automaticallyImplyLeading: false,
                toolbarHeight: 0,
                forceElevated: false,
                systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
                  statusBarColor: Colors.transparent,
                ),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: _ShopHeroCover(
                    shopName: shopName,
                    coverUrl: coverUrl,
                    supporterHeader: store.shopSupporterHeader,
                    regularCount: regularCount,
                    isOwner: isOwner,
                    badgeCount: badgeCount,
                    coverUploading: _avatarUploading,
                    onCoverPick: isOwner ? _pickAndUploadCover : null,
                    onPost: () => PostFirstCreationPage.open(context),
                    onNotifications: _openNotifications,
                    onSettings: _openSettings,
                    onComposeWhisper: () =>
                        showWhisperComposer(context, store: store),
                    onOpenFandom: () =>
                        MyPageFandomHubPage.open(context, store: store),
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyTabBarDelegate(
                  child: SoriYoutubeTabBar(
                    controller: _tabController,
                    labels: const [
                      'Home',
                      'Feed',
                      'Shop',
                      'Review',
                      'Seminar',
                      'AI',
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _HomeTabBody(
                store: store,
                shop: shop,
                bio: _bio,
                isOwner: isOwner,
                onOpenSeminarTab: () => _tabController.animateTo(4),
                onOpenFandom: () =>
                    MyPageFandomHubPage.open(context, store: store),
              ),
              _ServiceGroupedFeedTab(
                cases: cases,
                store: store,
                onOpenCasesTab: () => onSelectTab?.call(0),
              ),
              ShopInlineInfoTab(store: store, isOwner: isOwner),
              _ReviewTabBody(store: store),
              MySeminarTabBody(store: store, isOwner: isOwner),
              MyAiManagerTabBody(store: store, isOwner: isOwner),
            ],
          ),
        ),
      ),
    );
  }

  int _notificationBadgeCount(SessionUser? session) {
    if (session == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (session.activeMode == UserRole.director) {
      final careToday = store.customersForDate(today).length;
      final reviewReq = store.reviewRequestedPendingCount;
      final unreplied = store.reviewUnrepliedCount;
      return (careToday + reviewReq + unreplied).clamp(0, 99);
    }
    final cid = session.customerId;
    if (cid != null && store.isReviewRequested(cid)) return 1;
    return 0;
  }

  Future<void> _openNotifications() async {
    await pushRootPage<void>(
      context,
      Scaffold(
        backgroundColor: SoriTokens.background,
        appBar: AppBar(
          title: const Text('알림'),
          backgroundColor: SoriTokens.surface,
          foregroundColor: SoriTokens.textPrimary,
          elevation: 0,
        ),
        body: const MessageHistoryPage(embedded: true),
      ),
    );
  }

  Future<void> _openSettings() async {
    await pushRootPage<void>(
      context,
      AppSettingsPage(store: store),
    );
  }
}

/// 풀블리드 샵 간판 + 하단 다크 그라데이션 (Weverse 시네마틱).
class _ShopHeroCover extends StatelessWidget {
  const _ShopHeroCover({
    required this.shopName,
    required this.coverUrl,
    required this.supporterHeader,
    required this.regularCount,
    required this.isOwner,
    required this.onPost,
    required this.onNotifications,
    required this.onSettings,
    required this.onComposeWhisper,
    required this.onOpenFandom,
    this.onCoverPick,
    this.coverUploading = false,
    this.badgeCount = 0,
  });

  final String shopName;
  final String coverUrl;
  final ShopSupporterHeader supporterHeader;
  final int regularCount;
  final bool isOwner;
  final VoidCallback onPost;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;
  final VoidCallback onComposeWhisper;
  final VoidCallback onOpenFandom;
  final VoidCallback? onCoverPick;
  final bool coverUploading;
  final int badgeCount;

  static const _fallbackCover =
      'https://images.unsplash.com/photo-1560066984-138dadb4c035?auto=format&fit=crop&w=1400&q=80';

  @override
  Widget build(BuildContext context) {
    final src = coverUrl.trim().isNotEmpty ? coverUrl : _fallbackCover;
    final metric = supporterHeader.supporterCount > 0 ||
            supporterHeader.followerCount > 0
        ? supporterHeader.metricsLine
        : regularCount > 0
            ? '고객 $regularCount명 · 팔로워를 모아보세요'
            : '팔로워와 후원자를 모아보세요';

    return Stack(
      fit: StackFit.expand,
      children: [
        SoriNetworkImage(
          url: src,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          error: const ColoredBox(
            color: SoriTokens.primaryDark,
            child: Center(
              child: Icon(
                Icons.spa_rounded,
                size: 64,
                color: SoriTokens.primary,
              ),
            ),
          ),
        ),
        // 상단: 밝은 간판에서도 화이트 아이콘 가독성
        const Align(
          alignment: Alignment.topCenter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99000000),
                  Color(0x33000000),
                  Colors.transparent,
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
            child: SizedBox(height: 120, width: double.infinity),
          ),
        ),
        // 하단: 투명 → #0A0A0C
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.transparent,
                Color(0x990A0A0C),
                Color(0xFF0A0A0C),
              ],
              stops: [0.0, 0.42, 0.72, 1.0],
            ),
          ),
        ),
        // 우상단 오버레이 액션 (+ / 알림 / 설정)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  if (kDebugMode) const DebugModeChip(),
                  const Spacer(),
                  _HeroOverlayIcon(
                    tooltip: '새 게시물',
                    icon: Icons.add_rounded,
                    onPressed: onPost,
                  ),
                  _HeroOverlayIcon(
                    tooltip: '속삭임 작성',
                    icon: Icons.lock_outline_rounded,
                    onPressed: onComposeWhisper,
                  ),
                  _HeroOverlayIcon(
                    tooltip: '팔로워 · 구독',
                    icon: Icons.explore_outlined,
                    onPressed: onOpenFandom,
                  ),
                  _HeroOverlayIcon(
                    tooltip: '알림',
                    icon: Icons.notifications_none_rounded,
                    onPressed: onNotifications,
                    badgeCount: badgeCount,
                  ),
                  _HeroOverlayIcon(
                    tooltip: '설정',
                    icon: Icons.settings_outlined,
                    onPressed: onSettings,
                  ),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (supporterHeader.facepile.isNotEmpty)
                    ShopSupporterHeaderBanner(header: supporterHeader)
                  else
                    Text(
                      metric,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.78),
                        letterSpacing: 0.2,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    shopName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.12,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isOwner && onCoverPick != null)
          Positioned(
            right: 16,
            bottom: 28,
            child: SafeArea(
              top: false,
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: const CircleBorder(
                      side: BorderSide(color: Color(0x66FFFFFF)),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: coverUploading ? null : onCoverPick,
                      child: SizedBox(
                        width: 46,
                        height: 46,
                        child: Center(
                          child: coverUploading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.photo_camera_rounded,
                                  size: 20,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroOverlayIcon extends StatelessWidget {
  const _HeroOverlayIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Badge(
        isLabelVisible: badgeCount > 0,
        label: Text(
          '$badgeCount',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        backgroundColor: SoriTokens.systemRed,
        textColor: Colors.white,
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
          shadows: const [
            Shadow(
              color: Color(0xCC000000),
              blurRadius: 10,
              offset: Offset(0, 1),
            ),
            Shadow(
              color: Color(0x66000000),
              blurRadius: 2,
              offset: Offset(0, 0),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  _StickyTabBarDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: SoriTokens.background,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) =>
      child != oldDelegate.child;
}

class _SquircleCard extends StatelessWidget {
  const _SquircleCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SoriTokens.outlinePurple),
      ),
      child: child,
    );
  }
}

class _HomeTabBody extends StatelessWidget {
  const _HomeTabBody({
    required this.store,
    required this.shop,
    required this.bio,
    required this.isOwner,
    required this.onOpenSeminarTab,
    required this.onOpenFandom,
  });

  final SoriStore store;
  final Shop shop;
  final String bio;
  final bool isOwner;
  final VoidCallback onOpenSeminarTab;
  final VoidCallback onOpenFandom;

  @override
  Widget build(BuildContext context) {
    final owner = (shop.ownerName ?? '').trim();
    final ownerLabel = owner.isEmpty
        ? '${shop.name.trim().isEmpty ? 'SORI' : shop.name.trim()} 원장'
        : (owner.contains('원장') ? owner : '$owner 원장');
    final philosophy = bio.trim().isEmpty
        ? '피부와 사람을 잇는 섬세한 케어로, 방문할 때마다 더 빛나는 변화를 함께합니다.'
        : bio.trim();
    final avatarUrl = (shop.profileImageUrl ?? '').trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      children: [
        _SquircleCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DirectorAvatarButton(
                avatarUrl: avatarUrl,
                isOwner: isOwner,
                onPick: isOwner
                    ? () async {
                        final files = await openSoriInstaPicker(
                          context,
                          maxAssets: 1,
                          title: '프로필 사진',
                        );
                        if (files.isEmpty || !context.mounted) return;
                        final ok = await store.uploadShopProfileImage(
                          files.first,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok ? '프로필 사진이 업데이트되었어요' : '업로드에 실패했어요',
                            ),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: ok
                                ? SoriTokens.primary
                                : SoriTokens.primaryDark,
                          ),
                        );
                      }
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            ownerLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: SoriTokens.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        MyTierBadgeButton(shop: shop),
                        if (isOwner) ...[
                          const SizedBox(width: 2),
                          IconButton(
                            tooltip: '프로필 수정',
                            onPressed: () =>
                                showShopIdentityEditSheet(context, store),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            color: SoriTokens.primary,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      philosophy.length > 140
                          ? '${philosophy.substring(0, 140)}…'
                          : philosophy,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ShopPostsThreadSection(
          store: store,
          isOwner: isOwner,
          ownerLabel: ownerLabel,
          avatarUrl: avatarUrl,
        ),
        const SizedBox(height: 20),
        _SquircleCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.people_outline_rounded, color: SoriTokens.primary),
            title: const Text(
              '팔로워 · 구독',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: SoriTokens.textPrimary,
              ),
            ),
            subtitle: Text(
              store.subscriptionCount > 0
                  ? '팔로잉 ${store.subscriptionCount} · 홈 탐색에서 원장 찾기'
                  : '팔로잉 피드 · 원장 찾기는 홈 탐색',
              style: const TextStyle(
                fontSize: 12,
                color: SoriTokens.textSecondary,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: SoriTokens.textSecondary),
            onTap: onOpenFandom,
          ),
        ),
        const SizedBox(height: 12),
        _SquircleCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.school_outlined, color: SoriTokens.primary),
            title: const Text(
              'Seminar',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: SoriTokens.textPrimary,
              ),
            ),
            subtitle: const Text(
              '모집·신청·피드백을 Seminar 탭에서',
              style: TextStyle(fontSize: 12, color: SoriTokens.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: SoriTokens.textSecondary),
            onTap: onOpenSeminarTab,
          ),
        ),
      ],
    );
  }
}

class _DirectorAvatarButton extends StatefulWidget {
  const _DirectorAvatarButton({
    required this.avatarUrl,
    required this.isOwner,
    this.onPick,
  });

  final String avatarUrl;
  final bool isOwner;
  final Future<void> Function()? onPick;

  @override
  State<_DirectorAvatarButton> createState() => _DirectorAvatarButtonState();
}

class _DirectorAvatarButtonState extends State<_DirectorAvatarButton> {
  bool _busy = false;

  Future<void> _handlePick() async {
    if (_busy || widget.onPick == null) return;
    setState(() => _busy = true);
    try {
      await widget.onPick!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasNet = widget.avatarUrl.startsWith('http') ||
        widget.avatarUrl.startsWith('data:');
    final avatar = ClipOval(
      child: SizedBox(
        width: 64,
        height: 64,
        child: hasNet
            ? SoriNetworkImage(url: widget.avatarUrl, fit: BoxFit.cover)
            : const ColoredBox(
                color: SoriTokens.primarySoft,
                child: Icon(Icons.person_rounded,
                    size: 32, color: SoriTokens.primary),
              ),
      ),
    );
    if (!widget.isOwner || widget.onPick == null) return avatar;
    return GestureDetector(
      onTap: _busy ? null : _handlePick,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          if (_busy)
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x66000000),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: SoriTokens.primary,
                shape: BoxShape.circle,
                border: Border.all(color: SoriTokens.surface, width: 2),
              ),
              child: const Icon(
                Icons.photo_camera_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTabBody extends StatelessWidget {
  const _ReviewTabBody({required this.store});

  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final reviews = store.reviews
            .where(DirectorPeriodStats.isCompletedReview)
            .toList()
          ..sort((a, b) {
            final ad = a.createdAt ?? DateTime(1970);
            final bd = b.createdAt ?? DateTime(1970);
            return bd.compareTo(ad);
          });

        final rated = reviews.where((r) => r.effectiveRating > 0).toList();
        final avg = rated.isEmpty
            ? 0.0
            : rated.map((r) => r.effectiveRating).reduce((a, b) => a + b) /
                rated.length;

        if (reviews.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
            children: [
              const SizedBox(height: 48),
              const Icon(Icons.rate_review_outlined,
                  size: 48, color: SoriTokens.textSecondary),
              const SizedBox(height: 14),
              const Text(
                '작성된 리뷰가 없습니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: SoriTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '고객 후기가 등록되면 여기에 평점과 함께 표시됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: SoriTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: FilledButton.icon(
                  onPressed: () => showShopReviewComposeSheet(context, store),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('리뷰 작성'),
                  style: FilledButton.styleFrom(
                    backgroundColor: SoriTokens.primary,
                  ),
                ),
              ),
            ],
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          itemCount: reviews.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (i == 0) {
              return _SquircleCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '평균 평점',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: SoriTokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                avg.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: SoriTokens.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ...List.generate(
                                5,
                                (s) => Icon(
                                  s < avg.round()
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  size: 18,
                                  color: SoriTokens.warningText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '리뷰 ${reviews.length}건',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: SoriTokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () =>
                          showShopReviewComposeSheet(context, store),
                      style: FilledButton.styleFrom(
                        backgroundColor: SoriTokens.primary,
                      ),
                      child: const Text('작성'),
                    ),
                  ],
                ),
              );
            }

            final r = reviews[i - 1];
            final customer = store.findCustomer(r.customerId);
            return _SquircleCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ...List.generate(
                        r.effectiveRating.clamp(0, 5),
                        (_) => const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: SoriTokens.warningText,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        r.createdAt == null
                            ? ''
                            : '${r.createdAt!.month}/${r.createdAt!.day}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: SoriTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if ((customer?.name ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      customer!.name.trim(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    r.displayText.trim().isEmpty
                        ? '(내용 없음)'
                        : r.displayText.trim(),
                    softWrap: true,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: SoriTokens.textPrimary,
                    ),
                  ),
                  if ((r.directorReply ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '원장 답글 · ${r.directorReply!.trim()}',
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Feed 탭 — careName별 동적 가로 섹션 (Weverse 스타일).
class _ServiceGroupedFeedTab extends StatefulWidget {
  const _ServiceGroupedFeedTab({
    required this.cases,
    required this.store,
    required this.onOpenCasesTab,
  });

  final List<CustomerChart> cases;
  final SoriStore store;
  final VoidCallback onOpenCasesTab;

  @override
  State<_ServiceGroupedFeedTab> createState() => _ServiceGroupedFeedTabState();
}

class _ServiceGroupedFeedTabState extends State<_ServiceGroupedFeedTab> {
  static const double _sectionCardHeight = 260;
  static const double _cardWidth = 188;

  /// careName → charts (빌드마다 재계산 최소화용 캐시)
  Map<String, List<CustomerChart>> _grouped = const {};
  List<String> _sectionOrder = const [];
  List<CustomerChart>? _cachedSource;

  @override
  void initState() {
    super.initState();
    _rebuildGroups(widget.cases);
  }

  @override
  void didUpdateWidget(covariant _ServiceGroupedFeedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.cases, widget.cases) &&
        !_sameCaseIds(oldWidget.cases, widget.cases)) {
      _rebuildGroups(widget.cases);
    }
  }

  bool _sameCaseIds(List<CustomerChart> a, List<CustomerChart> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void _rebuildGroups(List<CustomerChart> cases) {
    _cachedSource = cases;
    final map = <String, List<CustomerChart>>{};
    for (final chart in cases) {
      final key = chart.careName.trim().isEmpty ? '기타 케어' : chart.careName.trim();
      (map[key] ??= <CustomerChart>[]).add(chart);
    }
    for (final list in map.values) {
      list.sort((a, b) {
        final ad = a.feedPostedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.feedPostedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
    }

    // serviceMenu 순서 우선, 그다음 게시물 수, 이름
    final menuOrder = widget.store.shop.serviceNames;
    final keys = map.keys.toList();
    keys.sort((a, b) {
      final ai = menuOrder.indexOf(a);
      final bi = menuOrder.indexOf(b);
      if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
      if (ai >= 0) return -1;
      if (bi >= 0) return 1;
      if (a == '기타 케어') return 1;
      if (b == '기타 케어') return -1;
      final ac = map[a]!.length;
      final bc = map[b]!.length;
      if (ac != bc) return bc.compareTo(ac);
      return a.compareTo(b);
    });

    _grouped = map;
    _sectionOrder = keys;
  }

  @override
  Widget build(BuildContext context) {
    if (!identical(_cachedSource, widget.cases) &&
        !_sameCaseIds(_cachedSource ?? const [], widget.cases)) {
      _rebuildGroups(widget.cases);
    }

    if (widget.cases.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            '등록된 B/A 케이스를 준비 중입니다 ✨\n차트에 Before/After를 남기면 서비스별로 모여요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SoriTokens.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 120),
      itemCount: _sectionOrder.length,
      itemBuilder: (context, sectionIndex) {
        final title = _sectionOrder[sectionIndex];
        final items = _grouped[title] ?? const <CustomerChart>[];
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onOpenCasesTab,
                      style: TextButton.styleFrom(
                        foregroundColor: SoriTokens.textSecondary,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        '더보기 >',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: _sectionCardHeight,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (_) => true,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      return SizedBox(
                        width: _cardWidth,
                        child: _FeedBaPostCard(
                          chart: items[i],
                          store: widget.store,
                          onTap: widget.onOpenCasesTab,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeedBaPostCard extends StatelessWidget {
  const _FeedBaPostCard({
    required this.chart,
    required this.store,
    required this.onTap,
  });

  final CustomerChart chart;
  final SoriStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final after = StorageImageUrl.resolve(chart.afterImageUrl);
    final before = StorageImageUrl.resolve(chart.beforeImageUrl);
    final url = (after ?? before ?? '').trim();
    final when = chart.relativeTimeLabel;
    // 커뮤니티 감성용 스테이블 더미 카운트 (로컬 해시)
    final likeSeed = chart.id.hashCode.abs();
    final likes = 12 + (likeSeed % 240);
    final comments = 2 + (likeSeed % 48);

    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: SoriTokens.outlinePurple),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: const Color(0xFF111113),
                      child: url.isEmpty
                          ? const Center(
                              child: Icon(
                                Icons.image_outlined,
                                color: SoriTokens.textSecondary,
                                size: 36,
                              ),
                            )
                          : Image.network(
                              url,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, _, _) => const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: SoriTokens.textSecondary,
                                  size: 32,
                                ),
                              ),
                            ),
                    ),
                    // 하단 가독성용 그라데이션
                    const Align(
                      alignment: Alignment.bottomCenter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0xCC18181B),
                            ],
                          ),
                        ),
                        child: SizedBox(height: 72, width: double.infinity),
                      ),
                    ),
                    if (before != null && after != null)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'B/A',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      when.isEmpty ? '최근' : when,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text('♡', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          '$likes',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: SoriTokens.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('💬', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          '$comments',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: SoriTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyTierTabBody extends StatelessWidget {
  const _MyTierTabBody({required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      children: [
        ShopTierProgressCard(shop: shop),
        const SizedBox(height: 14),
        if (shop.tierBadge.isVisible)
          Align(
            alignment: Alignment.centerLeft,
            child: ShopTierBadgeChip(badge: shop.tierBadge),
          ),
      ],
    );
  }
}

class _MySeminarTabBody extends StatelessWidget {
  const _MySeminarTabBody({
    required this.store,
    required this.onOpenClass,
  });

  final SoriStore store;
  final VoidCallback onOpenClass;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      children: [
        _SeminarEducationInsightCard(
          loading: store.seminarEducationLoading,
          totalRequests: store.seminarEducationInsight?.totalRequests ?? 0,
          soriCashBalance: store.shop.soriCashBalance,
          onOpenClass: onOpenClass,
        ),
        const SizedBox(height: 12),
        Material(
          color: SoriTokens.surface,
          borderRadius: BorderRadius.circular(14),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: SoriTokens.outlinePurple),
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SoriTokens.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('📊', style: TextStyle(fontSize: 18)),
            ),
            title: const Text(
              'AI 세미나 피드백 보관함',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
                color: SoriTokens.textPrimary,
              ),
            ),
            subtitle: Text(
              store.seminarFeedbackReportsLoading
                  ? '리포트 불러오는 중…'
                  : '완료 리포트 ${store.seminarFeedbackReports.length}건',
              style: const TextStyle(
                fontSize: 12,
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: SoriTokens.textSecondary,
            ),
            onTap: () => SeminarFeedbackInboxPage.open(context, store: store),
          ),
        ),
        const SizedBox(height: 12),
        _MySeminarEnrollmentsSection(store: store),
      ],
    );
  }
}

class _MyAiTabBody extends StatelessWidget {
  const _MyAiTabBody({
    required this.report,
    required this.onApply,
    required this.onDownload,
  });

  final AiShopReportMock report;
  final VoidCallback onApply;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      children: [
        _AiManagementSheetBody(
          report: report,
          onApply: onApply,
          onDownload: onDownload,
        ),
      ],
    );
  }
}

/// 퀵 대시보드 공통 바텀시트 — 화이트, 상단 라운드 24, PC maxWidth 500.
class _SoriQuickSheet extends StatelessWidget {
  const _SoriQuickSheet({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.88;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 500, maxHeight: maxH),
          child: Material(
            color: SoriTokens.surface,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.4),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: SoriTokens.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: SoriTokens.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '닫기',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AiManagementSheetBody extends StatelessWidget {
  const _AiManagementSheetBody({
    required this.report,
    required this.onApply,
    required this.onDownload,
  });

  final AiShopReportMock report;
  final VoidCallback onApply;
  final VoidCallback onDownload;

  String get _salesLabel {
    final won = report.revenue.estimatedSalesWon;
    if (won >= 100000000) {
      return '${(won / 100000000).toStringAsFixed(1)}억';
    }
    if (won >= 10000) {
      return '${_comma((won / 10000).round())}만원';
    }
    return '${_comma(won)}원';
  }

  String _comma(int n) {
    final s = '$n';
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final delta = report.revenue.salesDeltaPercent;
    final deltaLabel = delta >= 0
        ? '+${delta.toStringAsFixed(1)}%'
        : '${delta.toStringAsFixed(1)}%';
    final menus = report.portfolio.investMenus.take(2).toList();
    final month = DateTime.now().month;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: SoriTokens.card(radius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$month월 추정 성과',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: SoriTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _salesLabel,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: SoriTokens.primary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: delta >= 0
                          ? SoriTokens.primarySoft
                          : const Color(0x33EF4444),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '전월 대비 $deltaLabel',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: delta >= 0
                            ? SoriTokens.primary
                            : SoriTokens.systemRed.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.periodLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                report.revenue.highlight,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: SoriTokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: SoriTokens.card(radius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI 맞춤 제안',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: SoriTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '이번 달 추천 집중 메뉴',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SoriTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              ...menus.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: SoriTokens.primarySoft,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          m.tag,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: SoriTokens.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          m.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                report.targetSegment.summary,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: onApply,
          style: FilledButton.styleFrom(
            backgroundColor: SoriTokens.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'AI 솔루션 적용하기',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onDownload,
          style: OutlinedButton.styleFrom(
            foregroundColor: SoriTokens.textPrimary,
            side: const BorderSide(color: SoriTokens.border),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            '상세 리포트 다운로드',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _QuickDashboardRow extends StatelessWidget {
  const _QuickDashboardRow({
    required this.shop,
    required this.seminarRequestCount,
    required this.onTierTap,
    required this.onSeminarTap,
    required this.onAiTap,
  });

  final Shop shop;
  final int seminarRequestCount;
  final VoidCallback onTierTap;
  final VoidCallback onSeminarTap;
  final VoidCallback onAiTap;

  @override
  Widget build(BuildContext context) {
    final snap = shop.tierProgress;
    final progressPct =
        ((snap.socialRatio > snap.businessRatio
                    ? snap.socialRatio
                    : snap.businessRatio) *
                100)
            .round()
            .clamp(0, 100);
    final tierLabel = shop.tierBadge.label.trim();
    final tierSub = tierLabel.isNotEmpty ? tierLabel : '달성률 $progressPct%';
    final month = DateTime.now().month;

    return SizedBox(
      height: 92,
      child: Row(
        children: [
          Expanded(
            child: _QuickDashCard(
              icon: Icons.military_tech_rounded,
              iconColor: SoriTokens.textSecondary,
              iconBg: SoriTokens.warningBg,
              title: '내 등급',
              subtitle: tierSub,
              onTap: onTierTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickDashCard(
              icon: Icons.school_rounded,
              iconColor: SoriTokens.primary,
              iconBg: SoriTokens.primarySoft,
              title: '세미나 센터',
              subtitle: '요청 $seminarRequestCount건',
              onTap: onSeminarTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickDashCard(
              icon: Icons.auto_graph_rounded,
              iconColor: SoriTokens.primary,
              iconBg: SoriTokens.primarySoft,
              title: 'AI 경영',
              subtitle: '$month월 리포트',
              onTap: onAiTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickDashCard extends StatelessWidget {
  const _QuickDashCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoriTokens.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: SoriTokens.surface,
            borderRadius: BorderRadius.circular(16),
            border: SoriTokens.signatureBorder,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: SoriTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    color: SoriTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeminarEducationInsightCard extends StatelessWidget {
  const _SeminarEducationInsightCard({
    required this.loading,
    required this.totalRequests,
    required this.soriCashBalance,
    required this.onOpenClass,
  });

  final bool loading;
  final int totalRequests;
  final int soriCashBalance;
  final VoidCallback onOpenClass;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SoriTokens.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SoriTokens.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: SoriTokens.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '교육 수요 인사이트',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: SoriTokens.textPrimary,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '내 게시물 세미나 요청 $totalRequests건',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: SoriTokens.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'SORI Cash 잔액 ${soriCashBalance.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onOpenClass,
            style: FilledButton.styleFrom(
              backgroundColor: SoriTokens.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              '클래스 오픈하기',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}



class _MySeminarEnrollmentsSection extends StatelessWidget {
  const _MySeminarEnrollmentsSection({required this.store});

  final SoriStore store;

  Future<void> _complete(BuildContext context, SeminarEnrollment enrollment) async {
    final ok = await SeminarReviewModal.show(
      context,
      store: store,
      enrollmentId: enrollment.id,
      classId: enrollment.classId,
      classTitle: enrollment.classTitle,
    );
    if (!context.mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${enrollment.classTitle} 수강 후기가 저장되었어요'),
        backgroundColor: SoriTokens.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final held = store.mySeminarEnrollments.where((e) => e.isHeld).toList();
    if (store.mySeminarEnrollmentsLoading && held.isEmpty) {
      return const _FloatCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (held.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '내 세미나 수강',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: SoriTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ...held.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FloatCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.classTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: SoriTokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.amount > 0 ? '결제 ${e.amount}원' : '수강 확정',
                          style: const TextStyle(
                            fontSize: 12,
                            color: SoriTokens.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () => _complete(context, e),
                    style: FilledButton.styleFrom(
                      backgroundColor: SoriTokens.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    child: const Text(
                      '후기 작성',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FloatCard extends StatelessWidget {
  const _FloatCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  static final List<BoxShadow> _shadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: SoriTokens.signatureBorder,
        boxShadow: _shadow,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: content,
      ),
    );
  }
}
