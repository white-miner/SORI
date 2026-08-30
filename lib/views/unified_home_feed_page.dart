import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/community_case_item.dart';
import '../models/customer_chart.dart';
import '../models/home_feed_entry.dart';
import '../models/session_user.dart';
import '../models/shop.dart';
import '../pages/case_detail_page.dart';
import '../routing/sori_router.dart';
import '../services/sori_store.dart';
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
  final _liked = <String>{};
  final _likeCounts = <String, int>{};
  final _comments = <String, List<_FeedComment>>{};
  late final TabController _tabs;
  ScrollController? _mobileFeedScrollController;

  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(_onTabIndexChanged);
    store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshCommunityHotCases();
      store.refreshCommunityPosts();
      store.refreshUnifiedCommunityFeed();
      store.refreshShopFandomMeta();
      store.refreshCaseBookmarks();
      _consumePendingInnerTab();
    });
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    _tabs.removeListener(_onTabIndexChanged);
    _tabs.dispose();
    _mobileFeedScrollController?.dispose();
    super.dispose();
  }

  void _onTabIndexChanged() {
    if (_tabs.indexIsChanging) return;
    if (mounted) setState(() {});
  }

  ScrollController _activeFeedScrollController(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    if (wide) {
      final scoped = FeedScrollScope.maybeOf(context);
      if (scoped != null) return scoped;
    }
    return _mobileFeedScrollController ??= ScrollController();
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

  List<HomeFeedEntry> get _feed {
    if (store.homeFeedEntries.isNotEmpty) {
      return store.visibleHomeFeedEntries();
    }
    final hot = store.communityHotCases;
    final cases = hot.isNotEmpty ? hot : store.favoriteShopCaseItems();
    return cases.map(HomeFeedEntry.caseItem).toList();
  }

  List<CommunityCaseItem> get _localFeed => store.interleavedCaseFeed(
        viewerId: store.session?.id,
      );

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

  void _toggleLike(String chartId) {
    setState(() {
      final base = _likeCounts[chartId] ?? (5 + chartId.hashCode.abs() % 48);
      if (_liked.contains(chartId)) {
        _liked.remove(chartId);
        _likeCounts[chartId] = (base - 1).clamp(0, 9999);
      } else {
        _liked.add(chartId);
        _likeCounts[chartId] = base + 1;
      }
    });
  }

  Future<void> _toggleBookmark(String chartId) async {
    try {
      await store.toggleCaseBookmark(chartId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('보관함 저장에 실패했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openComments(CustomerChart chart) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200) {
      if (store.activeCommentPostId == chart.id) {
        store.closeCommentPanel();
      } else {
        store.openCommentPanel(chart.id);
      }
      return;
    }
    final list = _comments.putIfAbsent(chart.id, () => []);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _FeedCommentSheet(
          comments: list,
          onSubmit: (text) {
            final session = store.session;
            final author = session?.name.trim().isNotEmpty == true
                ? session!.name.trim()
                : '회원';
            setState(() {
              list.add(
                _FeedComment(
                  author: author,
                  body: text,
                  isDirector: session?.activeMode == UserRole.director,
                ),
              );
            });
          },
        );
      },
    );
  }

  void _openCaseDetail(
    CommunityCaseItem item,
    int feedIndex, {
    bool focusMentoring = false,
  }) {
    final id = item.chart.id;
    final likes = _likeCounts[id] ?? (5 + id.hashCode.abs() % 48);
    final comments = _comments[id] ?? const <_FeedComment>[];
    CaseDetailPage.push(
      context,
      page: CaseDetailPage(
        item: item,
        review: item.review ?? store.reviewForChart(item.chart.id),
        currentUserId: store.session?.id,
        liked: _liked.contains(id),
        likeCount: likes,
        commentCount: comments.length,
        bookmarked: store.isChartBookmarked(id),
        onLike: () => _toggleLike(id),
        onComment: () => _openComments(item.chart),
        onBookmark: () => _toggleBookmark(id),
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
    required String id,
    required int index,
    CommunityCaseItem? caseItem,
  }) {
    final likes = _likeCounts[id] ?? data.likeCount;
    final commentLen = (_comments[id] ?? const <_FeedComment>[]).length;
    final enriched = data.copyWithEngagement(
      likeCount: likes,
      commentCount: commentLen > 0 ? commentLen : data.commentCount,
    );
    final isDirector = store.session?.activeMode == UserRole.director;
    final isAuthor = caseItem?.isAuthoredBy(store.session?.id) ?? false;

    return SoriPostMedium(
      data: enriched,
      store: store,
      liked: _liked.contains(id),
      bookmarked:
          caseItem != null ? store.isChartBookmarked(id) : false,
      onLike: () => _toggleLike(id),
      onComment: caseItem != null
          ? () => _openComments(caseItem.chart)
          : () => openPostOriginal(context, data: enriched, store: store),
      onBookmark: caseItem != null ? () => _toggleBookmark(id) : () {},
      onShopProfile: caseItem != null
          ? () => _openShopProfile(caseItem.shop)
          : null,
      onMentoring: caseItem != null && caseItem.hasActiveMentoring
          ? () => _openCaseDetail(caseItem, index, focusMentoring: true)
          : isDirector && caseItem != null && !isAuthor
              ? () => _openMentoringRequest(caseItem)
              : null,
      onBoost: caseItem != null
          ? () {
              if (caseItem.isAuthoredBy(store.session?.id)) {
                _buyBoost(caseItem);
              } else {
                _buyFanBoost(caseItem);
              }
            }
          : null,
    );
  }

  Widget _feedCard(CommunityCaseItem item, int index) {
    return _mediumPost(
      PostViewData.fromCaseItem(item),
      id: item.chart.id,
      index: index,
      caseItem: item,
    );
  }

  Widget _buildHomeFeedEntry(HomeFeedEntry entry, int index) {
    final data = PostViewData.fromHomeFeedEntry(entry);
    final id = switch (entry.kind) {
      HomeFeedEntryKind.caseItem => entry.caseItem!.chart.id,
      HomeFeedEntryKind.seminar => entry.seminar!.id,
      HomeFeedEntryKind.publicWhisper => entry.whisperPost!.id,
    };
    return _mediumPost(
      data,
      id: id,
      index: index,
      caseItem: entry.caseItem,
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = _feed;
    final localFeed = _localFeed;
    final loading = store.communityHotCasesLoading && feed.isEmpty;
    final tabIndex = _tabs.index;
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final feedScroll = _activeFeedScrollController(context);

    final feedPane = TabBarView(
      controller: _tabs,
      children: [
        _RecommendFeedTab(
          store: store,
          feed: feed,
          loading: loading,
          buildEntry: _buildHomeFeedEntry,
          scrollController: tabIndex == 0 ? feedScroll : null,
        ),
        HomeExploreTab(
          store: store,
          scrollController: tabIndex == 1 ? feedScroll : null,
        ),
        _SimpleFeedTab(
          title: '우리 지역',
          subtitle: '부스터 적용 사례가 상단에 고정됩니다.',
          feed: localFeed,
          loading: loading,
          buildCard: _feedCard,
          scrollController: tabIndex == 2 ? feedScroll : null,
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

/// 추천 탭 — 히어로 + 탑 에듀케이터 + B/A 세로 피드.
class _RecommendFeedTab extends StatefulWidget {
  const _RecommendFeedTab({
    required this.store,
    required this.feed,
    required this.loading,
    required this.buildEntry,
    this.scrollController,
  });

  final SoriStore store;
  final List<HomeFeedEntry> feed;
  final bool loading;
  final Widget Function(HomeFeedEntry entry, int index) buildEntry;
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
          SliverToBoxAdapter(child: _SoriSpotMiniStrip(store: widget.store)),
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
                    child: widget.buildEntry(shown[index], index),
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
  const _SoriSpotMiniStrip({required this.store});

  final SoriStore store;

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
              return SizedBox(
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
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FeedComment {
  const _FeedComment({
    required this.author,
    required this.body,
    required this.isDirector,
  });

  final String author;
  final String body;
  final bool isDirector;
}

class _FeedCommentSheet extends StatefulWidget {
  const _FeedCommentSheet({
    required this.comments,
    required this.onSubmit,
  });

  final List<_FeedComment> comments;
  final ValueChanged<String> onSubmit;

  @override
  State<_FeedCommentSheet> createState() => _FeedCommentSheetState();
}

class _FeedCommentSheetState extends State<_FeedCommentSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.5,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SoriTokens.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '댓글',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: SoriTokens.textPrimary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: widget.comments.isEmpty
                  ? const Center(
                      child: Text(
                        '첫 댓글을 남겨 보세요',
                        style: TextStyle(color: SoriTokens.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      itemCount: widget.comments.length,
                      itemBuilder: (context, i) {
                        final c = widget.comments[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                color: SoriTokens.textPrimary,
                              ),
                              children: [
                                TextSpan(
                                  text: c.isDirector
                                      ? '${c.author} · 원장  '
                                      : '${c.author}  ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(text: c.body),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1, color: SoriTokens.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: SoriTokens.textPrimary),
                      decoration: InputDecoration(
                        hintText: '댓글 입력',
                        hintStyle:
                            const TextStyle(color: SoriTokens.textSecondary),
                        filled: true,
                        fillColor: SoriTokens.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    style: IconButton.styleFrom(
                      backgroundColor: SoriTokens.primary,
                    ),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
