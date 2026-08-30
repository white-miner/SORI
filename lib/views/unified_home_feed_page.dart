import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/habit/habit_feed_engine.dart';
import '../features/habit/insights_digest_card.dart';
import '../features/habit/story_rail_view.dart';
import '../models/community_case_item.dart';
import '../models/post_engagement_bindings.dart';
import '../models/session_user.dart';
import '../models/shop.dart';
import '../models/unified_feed_item.dart';
import '../pages/case_detail_page.dart';
import '../routing/sori_router.dart';
import '../services/engagement_service.dart';
import '../services/sori_store.dart';
import '../services/unified_feed_engine.dart';
import '../theme/sori_tab_indicator.dart';
import '../theme/sori_tokens.dart';
import '../utils/post_navigation.dart';
import '../widgets/post/post_view_data.dart';
import '../widgets/post/sori_post_medium.dart';
import '../widgets/post/sori_post_mini.dart';
import '../widgets/margin_scroll_forwarder.dart';
import '../widgets/app_scroll_behavior.dart';
import '../widgets/boost_purchase_sheet.dart';
import '../widgets/fan_boost_purchase_sheet.dart';
import '../widgets/mentoring_request_sheet.dart';
import '../widgets/proactive_mentoring_manage_sheet.dart';
import '../widgets/fan_sponsor_credits.dart';
import '../widgets/sori_logo.dart';
import '../widgets/shop_trust_score_card.dart';
import 'home_explore_tab.dart';
import 'seminar_class_detail_page.dart';

/// 원장·고객 공통 통합 커뮤니티 홈 — Weverse형 미디어 아키텍처.
class UnifiedHomeFeedPage extends StatefulWidget {
  const UnifiedHomeFeedPage({
    super.key,
    required this.store,
    this.onSelectTab,
  });

  final SoriStore store;
  final ValueChanged<int>? onSelectTab;

  @override
  State<UnifiedHomeFeedPage> createState() => _UnifiedHomeFeedPageState();
}

class _UnifiedHomeFeedPageState extends State<UnifiedHomeFeedPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  ScrollController? _recommendScrollController;
  ScrollController? _exploreScrollController;
  ScrollController? _localScrollController;

  SoriStore get store => widget.store;

  EngagementService get _engagement => EngagementService(
        context: context,
        store: store,
        onStateChanged: () {
          if (mounted) setState(() {});
        },
        onMentoringRequest: (data) {
          final item = data.caseItem ??
              (data.linkedChartId != null
                  ? store.communityCaseForChart(data.linkedChartId!)
                  : null);
          if (item != null) _openMentoringRequest(item);
        },
        onManageMentoring: (data) {
          final item = data.caseItem ??
              (data.linkedChartId != null
                  ? store.communityCaseForChart(data.linkedChartId!)
                  : null);
          if (item != null) _openManageMentoring(item);
        },
      );

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(_onTabIndexChanged);
    store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshUnifiedCommunityFeed();
      store.refreshShopFandomMeta();
      store.refreshCaseBookmarks();
      store.refreshChartLikes();
      _consumePendingInnerTab();
    });
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    _tabs.removeListener(_onTabIndexChanged);
    _tabs.dispose();
    _recommendScrollController?.dispose();
    _exploreScrollController?.dispose();
    _localScrollController?.dispose();
    super.dispose();
  }

  ScrollController _scrollForTab(int index) {
    switch (index) {
      case 1:
        return _exploreScrollController ??= ScrollController();
      case 2:
        return _localScrollController ??= ScrollController();
      case 0:
      default:
        return _recommendScrollController ??= ScrollController();
    }
  }

  ScrollController _activeFeedScrollController(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    if (wide) {
      final scoped = FeedScrollScope.maybeOf(context);
      if (scoped != null) return scoped;
    }
    return _scrollForTab(_tabs.index);
  }

  void _onTabIndexChanged() {
    if (_tabs.indexIsChanging) return;
    if (mounted) setState(() {});
  }

  void _onStore() {
    if (!mounted) return;
    _consumePendingInnerTab();
    setState(() {});
  }

  void _consumePendingInnerTab() {
    final pending = store.pendingHomeInnerTab;
    if (pending == null) return;
    store.pendingHomeInnerTab = null;
    final i = pending.clamp(0, 2);
    if (_tabs.index != i) {
      _tabs.animateTo(i);
    }
  }

  List<UnifiedFeedItem> get _recommendFeed =>
      UnifiedFeedEngine.recommendItems(store);

  List<CommunityCaseItem> get _localFeed => store.interleavedCaseFeed(
        viewerId: store.session?.id,
      );

  CommunityCaseItem? _caseItemFor(PostViewData data) {
    if (data.caseItem != null) return data.caseItem;
    final linked = data.linkedChartId?.trim();
    if (linked != null && linked.isNotEmpty) {
      return store.communityCaseForChart(linked);
    }
    return null;
  }

  PostEngagementBindings _bindingsFor(
    PostViewData data, {
    CommunityCaseItem? caseItem,
  }) {
    final item = caseItem ?? _caseItemFor(data);
    return _engagement.bindingsForWithBoost(
      data,
      onBoostTap: () {
        if (item == null) return;
        if (item.isAuthoredBy(store.session?.id)) {
          _buyBoost(item);
        } else {
          _buyFanBoost(item);
        }
      },
    );
  }

  Future<void> _buyBoost(CommunityCaseItem item) async {
    final ok = await showBoostPurchaseSheet(
      context,
      store: store,
      chartId: item.chart.id,
      caseTitle: item.chart.careName,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('노출 부스터가 적용되었습니다. 우리 지역 피드 슬롯에 혼합 노출돼요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _buyFanBoost(CommunityCaseItem item) async {
    final cid = store.session?.customerId?.trim() ?? '';
    if (cid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('고객 로그인 후 부스터 후원을 사용할 수 있어요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final ok = await showFanBoostPurchaseSheet(
      context,
      store: store,
      chartId: item.chart.id,
      targetShopId: item.shop.id,
      caseTitle: item.chart.careName,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('부스터 후원이 적용되었습니다! 원장님에게 알림이 전달돼요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openCaseDetail(
    CommunityCaseItem item,
    int feedIndex, {
    bool focusMentoring = false,
  }) {
    final data = PostViewData.fromCaseItem(item);
    final bindings = _bindingsFor(data, caseItem: item);
    CaseDetailPage.push(
      context,
      page: CaseDetailPage(
        item: item,
        review: item.review ?? store.reviewForChart(item.chart.id),
        currentUserId: store.session?.id,
        liked: bindings.liked,
        likeCount: bindings.likeCount,
        commentCount: bindings.commentCount,
        bookmarked: bindings.bookmarked,
        onLike: bindings.onLike,
        onComment: bindings.onComment,
        onBookmark: bindings.onBookmark,
        onShopProfile: () => _openShopProfile(item.shop),
        onBookingCta: () => _openNaverBookingOrProfile(item.shop),
        focusMentoringSection: focusMentoring,
      ),
    );
  }

  Future<void> _openManageMentoring(CommunityCaseItem item) async {
    final ok = await showProactiveMentoringManageSheet(
      context,
      store: store,
      item: item,
    );
    if (!mounted || !ok) return;
    setState(() {});
  }

  void _openSeminarDetail(String classId) {
    SeminarClassDetailPage.open(
      context,
      store: store,
      classId: classId,
    );
  }

  void _openSourceCaseFromSeminar(String? chartId) {
    final id = chartId?.trim() ?? '';
    if (id.isEmpty) return;
    final item = store.communityCaseForChart(id);
    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('원본 B/A 케이스를 불러올 수 없습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _openCaseDetail(item, 0);
  }

  Future<void> _openMentoringRequest(CommunityCaseItem item) async {
    final ok = await showMentoringRequestSheet(
      context,
      store: store,
      item: item,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('멘토링 요청이 전달되었습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openNaverBookingOrProfile(Shop shop) async {
    final url = shop.naverBookingOrPlaceUrl;
    if (url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
    }
    await _openShopProfile(shop);
  }

  Future<void> _openShopProfile(Shop shop) async {
    if (shop.id == store.shop.id && widget.onSelectTab != null) {
      widget.onSelectTab!(4);
      return;
    }
    if (shop.id == store.shop.id && context.mounted) {
      context.go(AppPaths.appMy);
      return;
    }

    if (!mounted) return;
    await store.refreshShopTrustScore(shop.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final avatar = shop.profileImageUrl?.trim() ?? '';
        final bio = shop.bio.trim();
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: SoriTokens.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              CircleAvatar(
                radius: 36,
                backgroundColor: SoriTokens.primarySoft,
                backgroundImage:
                    avatar.isNotEmpty && !avatar.startsWith('data:')
                        ? NetworkImage(avatar)
                        : null,
                child: avatar.isEmpty || avatar.startsWith('data:')
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SoriLogo(width: 40, height: 40),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                shop.name.trim().isEmpty ? 'SORI 샵' : shop.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: SoriTokens.textPrimary,
                ),
              ),
              if ((shop.ownerName ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '원장 ${shop.ownerName}',
                  style: const TextStyle(
                    color: SoriTokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ShopTrustScoreCard(
                trust: store.trustScoreForShop(shop.id),
                compact: true,
              ),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  bio,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: SoriTokens.textPrimary,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ShopTopSupportersSection(
                entries: ShopTopSupportersSection.fromBoosts(
                  store.activeBoostPlacements,
                  shopId: shop.id,
                ),
              ),
              const SizedBox(height: 16),
              if (shop.naverBookingOrPlaceUrl.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openNaverBookingOrProfile(shop);
                    },
                    child: const Text('[네이버 예약]'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _mediumPost(
    PostViewData data, {
    required int index,
    CommunityCaseItem? caseItem,
  }) {
    final item = caseItem ?? _caseItemFor(data);
    final engagement = _bindingsFor(data, caseItem: item);
    final enriched = data.copyWithEngagement(
      likeCount: engagement.likeCount,
      commentCount: engagement.commentCount,
    );

    return SoriPostMedium(
      data: enriched,
      store: store,
      engagement: engagement,
      onShopProfile:
          item != null ? () => _openShopProfile(item.shop) : null,
    );
  }

  Widget _feedCard(CommunityCaseItem item, int index) {
    return _mediumPost(
      PostViewData.fromCaseItem(item),
      index: index,
      caseItem: item,
    );
  }

  Widget _buildUnifiedItem(UnifiedFeedItem item, int index) {
    final data = PostViewData.fromUnifiedFeedItem(item);
    return _mediumPost(
      data,
      index: index,
      caseItem: item.caseItem,
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = _recommendFeed;
    final localFeed = _localFeed;
    final loading = store.unifiedFeedLoading && feed.isEmpty;
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final feedScroll = _activeFeedScrollController(context);

    final feedPane = TabBarView(
      controller: _tabs,
      children: [
        _RecommendFeedTab(
          store: store,
          feed: feed,
          loading: loading,
          buildItem: _buildUnifiedItem,
          engagementBuilder: (item) =>
              _bindingsFor(PostViewData.fromUnifiedFeedItem(item)),
          scrollController: _scrollForTab(0),
        ),
        HomeExploreTab(
          store: store,
          scrollController: _scrollForTab(1),
        ),
        _SimpleFeedTab(
          title: '우리 지역',
          subtitle: '부스터 적용 사례가 상단에 고정됩니다.',
          feed: localFeed,
          loading: loading,
          buildCard: _feedCard,
          scrollController: _scrollForTab(2),
        ),
      ],
    );

    final wheelWrapped = FeedScrollWheelWrapper(
      controller: feedScroll,
      child: feedPane,
    );

    final expandedFeed = wide
        ? wheelWrapped
        : FeedScrollScopeBinder(
            controller: feedScroll,
            child: wheelWrapped,
          );

    return ColoredBox(
      color: SoriTokens.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: SoriTokens.background,
              child: SoriYoutubeTabBar(
                controller: _tabs,
                labels: const ['추천', '탐색', '우리 지역'],
              ),
            ),
            Expanded(child: expandedFeed),
          ],
        ),
      ),
    );
  }
}

/// 추천 탭 — 히어로 + 탑 에듀케이터 + 통합 SSOT 피드.
class _RecommendFeedTab extends StatefulWidget {
  const _RecommendFeedTab({
    required this.store,
    required this.feed,
    required this.loading,
    required this.buildItem,
    required this.engagementBuilder,
    this.scrollController,
  });

  final SoriStore store;
  final List<UnifiedFeedItem> feed;
  final bool loading;
  final Widget Function(UnifiedFeedItem item, int index) buildItem;
  final PostEngagementBindings Function(UnifiedFeedItem item) engagementBuilder;
  final ScrollController? scrollController;

  @override
  State<_RecommendFeedTab> createState() => _RecommendFeedTabState();
}

class _RecommendFeedTabState extends State<_RecommendFeedTab>
    with AutomaticKeepAliveClientMixin {
  int _visibleCount = 10;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final shown = widget.feed.take(_visibleCount).toList();
    final scrollActive = widget.scrollController != null;
    const scrollPhysics = AlwaysScrollableScrollPhysics(
      parent: ClampingScrollPhysics(),
    );
    final tabPhysics = scrollActive ? scrollPhysics : const NeverScrollableScrollPhysics();

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (!scrollActive) return false;
        if (n.metrics.axis != Axis.vertical) return false;
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 160) {
          if (_visibleCount < widget.feed.length) {
            setState(() {
              _visibleCount = (_visibleCount + 8).clamp(0, widget.feed.length);
            });
          }
        }
        return false;
      },
      child: ScrollConfiguration(
        behavior: const SoriScrollBehavior(),
        child: CustomScrollView(
          controller: widget.scrollController,
          physics: tabPhysics,
          slivers: [
          SliverToBoxAdapter(
            child: InsightsDigestCard(store: widget.store),
          ),
          SliverToBoxAdapter(
            child: StoryRailView(
              items: HabitFeedEngine.storyRailItems(widget.store),
              store: widget.store,
              engagementBuilder: widget.engagementBuilder,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 4)),
          SliverToBoxAdapter(
            child: _SoriSpotMiniStrip(
              store: widget.store,
              engagementBuilder: widget.engagementBuilder,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          const SliverToBoxAdapter(child: _TopEducatorsStrip()),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                '오늘의 피드',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: SoriTokens.textPrimary,
                ),
              ),
            ),
          ),
          if (widget.loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: SoriTokens.primary),
              ),
            )
          else if (shown.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    '아직 피드 콘텐츠가 없어요.\nB/A · 세미나 · Whisper가 곧 올라올 예정이에요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SoriTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 110),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => FeedScrollRow(
                    child: widget.buildItem(shown[index], index),
                  ),
                  childCount: shown.length,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }
}

/// 우리 지역 — KeepAlive 세로 피드.
class _SimpleFeedTab extends StatefulWidget {
  const _SimpleFeedTab({
    required this.title,
    required this.subtitle,
    required this.feed,
    required this.loading,
    required this.buildCard,
    this.scrollController,
  });

  final String title;
  final String subtitle;
  final List<CommunityCaseItem> feed;
  final bool loading;
  final Widget Function(CommunityCaseItem item, int index) buildCard;
  final ScrollController? scrollController;

  @override
  State<_SimpleFeedTab> createState() => _SimpleFeedTabState();
}

class _SimpleFeedTabState extends State<_SimpleFeedTab>
    with AutomaticKeepAliveClientMixin {
  int _visibleCount = 10;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final shown = widget.feed.take(_visibleCount).toList();
    final scrollActive = widget.scrollController != null;
    const scrollPhysics = AlwaysScrollableScrollPhysics(
      parent: ClampingScrollPhysics(),
    );
    final tabPhysics = scrollActive ? scrollPhysics : const NeverScrollableScrollPhysics();

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (!scrollActive) return false;
        if (n.metrics.axis != Axis.vertical) return false;
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 160) {
          if (_visibleCount < widget.feed.length) {
            setState(() {
              _visibleCount = (_visibleCount + 8).clamp(0, widget.feed.length);
            });
          }
        }
        return false;
      },
      child: ScrollConfiguration(
        behavior: const SoriScrollBehavior(),
        child: CustomScrollView(
          controller: widget.scrollController,
          physics: tabPhysics,
          slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: SoriTokens.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: SoriTokens.primary),
              ),
            )
          else if (shown.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    '아직 공유된 B/A 피드가 없어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SoriTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 110),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => FeedScrollRow(
                    child: widget.buildCard(shown[index], index),
                  ),
                  childCount: shown.length,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }
}

/// Home SORI Spot — boosted / popular mini cards (horizontal).
class _SoriSpotMiniStrip extends StatelessWidget {
  const _SoriSpotMiniStrip({
    required this.store,
    required this.engagementBuilder,
  });

  final SoriStore store;
  final PostEngagementBindings Function(UnifiedFeedItem item) engagementBuilder;

  @override
  Widget build(BuildContext context) {
    final items = store.spotlightMiniFeedItems();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'SORI Spot',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: SoriTokens.textPrimary,
            ),
          ),
        ),
        SoriPostMini.horizontalStrip(
          children: [
            for (final item in items)
              SoriPostMini(
                key: ValueKey('spot_${item.stableKey}'),
                data: PostViewData.fromUnifiedFeedItem(item),
                store: store,
                horizontal: true,
                engagement: engagementBuilder(item),
              ),
          ],
        ),
      ],
    );
  }
}

/// 탑 에듀케이터 — 고정 높이 가로 스크롤 (제스처 독립).
class _TopEducatorsStrip extends StatelessWidget {
  const _TopEducatorsStrip();

  static const _educators = <({String name, String initial, String meta})>[
    (name: '김서연 원장', initial: '김', meta: '장벽·민감'),
    (name: '박지훈 원장', initial: '박', meta: '리프팅'),
    (name: '이하늘 원장', initial: '이', meta: '여드름'),
    (name: '최민정 원장', initial: '최', meta: '웨딩케어'),
    (name: '정우성 원장', initial: '정', meta: '체형'),
    (name: '한소희 원장', initial: '한', meta: '홍조'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            '탑 에듀케이터',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: SoriTokens.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _educators.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final e = _educators[index];
              return GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('준비 중입니다'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: SizedBox(
                width: 88,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: SoriTokens.primarySoft,
                      child: Text(
                        e.initial,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: SoriTokens.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: SoriTokens.textPrimary,
                      ),
                    ),
                    Text(
                      e.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              );
            },
          ),
        ),
      ],
    );
  }
}

