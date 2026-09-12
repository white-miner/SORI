import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/habit/insights_pulse_strip.dart';
import '../features/habit/top_mentor_strip.dart';
import '../models/recommend_feed_category.dart';
import '../models/community_case_item.dart';
import '../models/feed_query_config.dart';
import '../models/post_engagement_bindings.dart';
import '../models/shop.dart';
import '../models/unified_feed_item.dart';
import '../pages/case_detail_page.dart';
import '../routing/sori_router.dart';
import '../services/engagement_service.dart';
import '../services/sori_store.dart';
import '../services/unified_feed_engine.dart';
import '../theme/sori_tab_indicator.dart';
import '../theme/sori_tokens.dart';
import '../utils/category_presentation_map.dart';
import '../utils/sori_feed_scroll_physics.dart';
import '../utils/sori_shell_insets.dart';
import '../widgets/post/post_view_data.dart';
import '../widgets/post/sori_post_medium.dart';
import '../widgets/post/sori_post_mini.dart';
import '../widgets/margin_scroll_forwarder.dart';
import '../widgets/boost_purchase_sheet.dart';
import '../widgets/fan_boost_purchase_sheet.dart';
import '../widgets/mentoring_request_sheet.dart';
import '../widgets/proactive_mentoring_manage_sheet.dart';
import '../widgets/fan_sponsor_credits.dart';
import '../widgets/sori_logo.dart';
import '../widgets/shop_trust_score_card.dart';
import '../utils/region_feed_filter.dart';
import 'community/region_nearby_map_section.dart';
import 'home_explore_tab.dart';
import 'seminar_class_detail_page.dart';

/// Last-card breathing. Shell occupancy is [SoriShellInsets.scrollBottomInset].
const double _kFeedListBreathing = 8;

EdgeInsets _feedListPadding(BuildContext context) {
  return EdgeInsets.fromLTRB(
    0,
    _kFeedListBreathing,
    0,
    _kFeedListBreathing + SoriShellInsets.scrollBottomInset(context),
  );
}

class UnifiedHomeFeedPage extends StatefulWidget {
  const UnifiedHomeFeedPage({
    super.key,
    required this.store,
    this.onSelectTab,
    this.surface = FeedSurface.community,
  });

  final SoriStore store;
  final ValueChanged<int>? onSelectTab;

  /// Default [FeedSurface.community] keeps legacy mounts behavior-preserving.
  final FeedSurface surface;

  @override
  State<UnifiedHomeFeedPage> createState() => _UnifiedHomeFeedPageState();
}

class _UnifiedHomeFeedPageState extends State<UnifiedHomeFeedPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  ScrollController? _recommendScrollController;
  ScrollController? _exploreScrollController;
  ScrollController? _localScrollController;

  /// 우리 지역 맵·피드 공통 반경 (PRD v7.8 C3).
  double _regionRadiusKm = 1.0;
  double? _regionCenterLat;
  double? _regionCenterLng;

  SoriStore get store => widget.store;

  FeedQueryConfig get _config => FeedQueryConfig.forSurface(widget.surface);

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
    _tabs = TabController(length: _tabLength, vsync: this);
    _tabs.addListener(_onTabIndexChanged);
    store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshUnifiedCommunityFeed();
      store.refreshShopFandomMeta();
      store.refreshCaseBookmarks();
      store.refreshChartLikes();
      store.refreshDiscoverDirectors(soft: true);
      _consumePendingInnerTab();
    });
  }

  int get _tabLength {
    var n = 1;
    if (_config.showExploreTab) n++;
    if (_config.showLocalTab) n++;
    return n;
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
        return _exploreScrollController ??= SoriFeedScrollController();
      case 2:
        return _localScrollController ??= SoriFeedScrollController();
      case 0:
      default:
        return _recommendScrollController ??= SoriFeedScrollController();
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
    // Home surface has recommend-only chrome — ignore explore/local jumps.
    if (!_config.showExploreTab && !_config.showLocalTab) {
      if (_tabs.index != 0) _tabs.animateTo(0);
      return;
    }
    final i = pending.clamp(0, _tabs.length - 1);
    if (_tabs.index != i) {
      _tabs.animateTo(i);
    }
  }

  List<UnifiedFeedItem> get _recommendFeed =>
      UnifiedFeedEngine.recommendItems(store, config: _config);

  List<CommunityCaseItem> get _localFeed {
    final base = store.interleavedCaseFeed(
      viewerId: store.session?.id,
    );
    return RegionFeedFilter.byRadiusKm(
      base,
      centerLat: _regionCenterLat ?? store.shop.latitude,
      centerLng: _regionCenterLng ?? store.shop.longitude,
      radiusKm: _regionRadiusKm,
    );
  }

  String _regionRadiusLabel(double km) {
    if (km < 1) return '${(km * 1000).round()}m';
    if (km == km.roundToDouble()) return '${km.toInt()}km';
    return '${km}km';
  }

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
    if (!_config.boostAllowed) {
      final base = _engagement.bindingsFor(data);
      return PostEngagementBindings(
        liked: base.liked,
        bookmarked: base.bookmarked,
        likeCount: base.likeCount,
        commentCount: base.commentCount,
        onLike: base.onLike,
        onComment: base.onComment,
        onBookmark: base.onBookmark,
        onMentoring: base.onMentoring,
        onBoost: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('홈에서는 부스터를 쓰지 않아요. 커뮤니티에서 이용할 수 있어요.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        likeEnabled: base.likeEnabled,
        commentEnabled: base.commentEnabled,
        bookmarkEnabled: base.bookmarkEnabled,
        mentoringEnabled: base.mentoringEnabled,
        boostEnabled: false,
        likeDisabledReason: base.likeDisabledReason,
        commentDisabledReason: base.commentDisabledReason,
        bookmarkDisabledReason: base.bookmarkDisabledReason,
        mentoringDisabledReason: base.mentoringDisabledReason,
        boostDisabledReason: '홈에서는 부스터를 쓰지 않아요.',
      );
    }
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
      engagement: _config.surface == FeedSurface.home ? null : engagement,
      glanceMode: _config.surface == FeedSurface.home,
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
    final config = _config;

    final tabChildren = <Widget>[
      _RecommendFeedTab(
        store: store,
        feed: feed,
        loading: loading,
        buildItem: _buildUnifiedItem,
        engagementBuilder: (item) =>
            _bindingsFor(PostViewData.fromUnifiedFeedItem(item)),
        scrollController: _scrollForTab(0),
        homeGlance: config.surface == FeedSurface.home,
      ),
    ];
    final labels = <String>[
      config.surface == FeedSurface.home ? '추천 글' : '추천',
    ];
    if (config.showExploreTab) {
      labels.add('탐색');
      tabChildren.add(
        HomeExploreTab(
          store: store,
          scrollController: _scrollForTab(1),
        ),
      );
    }
    if (config.showLocalTab) {
      labels.add('우리 지역');
      final localIndex = tabChildren.length;
      tabChildren.add(
        _SimpleFeedTab(
          store: store,
          title: '우리 지역',
          subtitle:
              '지도 반경 ${_regionRadiusLabel(_regionRadiusKm)} 안 샵·게시물만 보여요.',
          feed: localFeed,
          loading: loading,
          buildCard: _feedCard,
          scrollController: _scrollForTab(localIndex),
          regionRadiusKm: _regionRadiusKm,
          onRegionRadiusChanged: (km) {
            setState(() => _regionRadiusKm = km);
          },
          onRegionCenterChanged: (lat, lng) {
            setState(() {
              _regionCenterLat = lat;
              _regionCenterLng = lng;
            });
          },
          regionCenterReady: (() {
            final lat = _regionCenterLat ?? store.shop.latitude;
            final lng = _regionCenterLng ?? store.shop.longitude;
            return lat != null &&
                lng != null &&
                lat.abs() > 0.01 &&
                lng.abs() > 0.01;
          })(),
        ),
      );
    }

    final feedPane = TabBarView(
      controller: _tabs,
      children: tabChildren,
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
            if (labels.length > 1)
              Material(
                color: SoriTokens.background,
                child: SoriYoutubeTabBar(
                  controller: _tabs,
                  labels: labels,
                ),
              )
            else
              Material(
                color: SoriTokens.background,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          labels.first,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: SoriTokens.textPrimary,
                          ),
                        ),
                      ),
                      if (config.surface == FeedSurface.home &&
                          widget.onSelectTab != null)
                        TextButton(
                          onPressed: () => widget.onSelectTab!(3),
                          style: TextButton.styleFrom(
                            foregroundColor: SoriTokens.textSecondary,
                            minimumSize: const Size(48, 40),
                          ),
                          child: Text(
                            CategoryPresentationMap.viewPost,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
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
    this.homeGlance = false,
  });

  final SoriStore store;
  final List<UnifiedFeedItem> feed;
  final bool loading;
  final Widget Function(UnifiedFeedItem item, int index) buildItem;
  final PostEngagementBindings Function(UnifiedFeedItem item) engagementBuilder;
  final ScrollController? scrollController;
  final bool homeGlance;

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
    final tabPhysics = scrollActive
        ? soriFeedScrollPhysics
        : const NeverScrollableScrollPhysics();

    final scrollView = ScrollConfiguration(
      behavior: const SoriFeedScrollBehavior(),
      child: CustomScrollView(
        key: const Key('feed-recommend-scroll'),
        controller: widget.scrollController,
        physics: tabPhysics,
        slivers: [
          if (!widget.homeGlance) ...[
            SliverToBoxAdapter(
              child: InsightsPulseStrip(store: widget.store),
            ),
            SliverToBoxAdapter(
              child: TopMentorStrip(store: widget.store),
            ),
            SliverToBoxAdapter(
              child: _LatestPostsStrip(
                store: widget.store,
                engagementBuilder: widget.engagementBuilder,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 4)),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                widget.homeGlance ? '오늘 보면 좋은 글' : '오늘의 피드',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: SoriTokens.textPrimary,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                widget.homeGlance
                    ? '가벼운 추천만 보여 드려요. 탐색·작성은 커뮤니티에서.'
                    : '전후 · 세미나 · 리뷰 · 멘토 — 전국에서 오늘 올라온 글',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: SoriTokens.textSecondary,
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
                    '아직 피드 콘텐츠가 없어요.\nB/A · 세미나 · 조용한 이야기가 곧 올라올 예정이에요.',
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
              key: const Key('feed-recommend-list-padding'),
              padding: _feedListPadding(context),
              sliver: Builder(
                builder: (context) {
                  final rows = <({String? section, UnifiedFeedItem? item})>[];
                  String? lastSection;
                  for (final item in shown) {
                    final section =
                        RecommendFeedCategory.daySectionLabel(item.sortAt);
                    if (section != lastSection) {
                      rows.add((section: section, item: null));
                      lastSection = section;
                    }
                    rows.add((section: null, item: item));
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final row = rows[index];
                        if (row.section != null) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                            child: Text(
                              row.section!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: SoriTokens.textSecondary,
                              ),
                            ),
                          );
                        }
                        final item = row.item!;
                        final feedIndex = shown.indexOf(item);
                        return FeedScrollRow(
                          child: widget.buildItem(item, feedIndex),
                        );
                      },
                      childCount: rows.length,
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: true,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );

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
      child: scrollActive
          ? RefreshIndicator(
              key: const Key('feed-recommend-refresh'),
              color: SoriTokens.primary,
              onRefresh: () => widget.store.refreshUnifiedCommunityFeed(
                force: true,
              ),
              child: scrollView,
            )
          : scrollView,
    );
  }
}

/// 우리 지역 — KeepAlive 세로 피드.
class _SimpleFeedTab extends StatefulWidget {
  const _SimpleFeedTab({
    required this.store,
    required this.title,
    required this.subtitle,
    required this.feed,
    required this.loading,
    required this.buildCard,
    this.scrollController,
    this.regionRadiusKm = 1.0,
    this.onRegionRadiusChanged,
    this.onRegionCenterChanged,
    this.regionCenterReady = false,
  });

  final SoriStore store;
  final String title;
  final String subtitle;
  final List<CommunityCaseItem> feed;
  final bool loading;
  final Widget Function(CommunityCaseItem item, int index) buildCard;
  final ScrollController? scrollController;
  final double regionRadiusKm;
  final ValueChanged<double>? onRegionRadiusChanged;
  final void Function(double? lat, double? lng)? onRegionCenterChanged;
  final bool regionCenterReady;

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
    final tabPhysics = scrollActive
        ? soriFeedScrollPhysics
        : const NeverScrollableScrollPhysics();

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
        behavior: const SoriFeedScrollBehavior(),
        child: CustomScrollView(
          key: const Key('feed-local-scroll'),
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
                  const SizedBox(height: 14),
                  RegionNearbyMapSection(
                    store: widget.store,
                    radiusKm: widget.regionRadiusKm,
                    onRadiusChanged: widget.onRegionRadiusChanged,
                    onCenterChanged: widget.onRegionCenterChanged,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '우리 동네 게시물',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.regionCenterReady
                        ? '지도와 같은 반경 안 · 좌표 있는 샵 글만 모아요'
                        : '주소를 잡으면 근처 글만 보여 드려요',
                    style: const TextStyle(
                      fontSize: 12,
                      color: SoriTokens.textSecondary,
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
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    widget.regionCenterReady
                        ? '이 반경 안에 공유된 B/A가 아직 없어요.\n반경을 넓혀 보거나 나중에 다시 확인해 주세요.'
                        : '샵 주소(또는 위치)가 있으면\n근처 게시물만 모아 보여 드려요.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: SoriTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              key: const Key('feed-local-list-padding'),
              padding: _feedListPadding(context),
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

/// 최신 게시물 — spotlight mini cards (PRD v3.1).
class _LatestPostsStrip extends StatelessWidget {
  const _LatestPostsStrip({
    required this.store,
    required this.engagementBuilder,
  });

  final SoriStore store;
  final PostEngagementBindings Function(UnifiedFeedItem item) engagementBuilder;

  @override
  Widget build(BuildContext context) {
    final items = store.spotlightMiniFeedItems();
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Text(
            '최신 게시물',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: SoriTokens.textPrimary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            '실시간 · 부스트 · 인기',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: SoriTokens.textSecondary.withValues(alpha: 0.85),
            ),
          ),
        ),
        SoriPostMini.horizontalStrip(
          children: [
            for (final item in items)
              SoriPostMini(
                key: ValueKey('latest_${item.stableKey}'),
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

