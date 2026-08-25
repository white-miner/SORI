import 'package:flutter/material.dart';

import '../models/community_case_item.dart';
import '../models/customer_chart.dart';
import '../models/session_user.dart';
import '../models/shop_gallery_slide.dart';
import '../models/shop_highlight.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_nav.dart';
import '../widgets/sori_logo.dart';
import 'ba_reels_detail_page.dart';

/// 고객 모드 홈 — Instagram형 원장 팬덤 프로필 + 하이브리드 피드.
/// 차트/리뷰 비즈니스 로직은 Store·Repository에 두고 UI만 재구성한다.
class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({
    super.key,
    required this.store,
    this.onSelectTab,
  });

  final SoriStore store;
  final ValueChanged<int>? onSelectTab;

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshShopFandomMeta();
      store.refreshCommunityHotCases();
    });
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    _tabController.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  List<CommunityCaseItem> get _baCases => store.favoriteShopCaseItems();

  CustomerChart? get _latestMyCare {
    final cid = store.session?.customerId;
    if (cid == null || cid.isEmpty) return null;
    return store.latestChart(cid);
  }

  bool get _needsReviewCta {
    final chart = _latestMyCare;
    if (chart == null) return false;
    final review = store.reviewForChart(chart.id);
    if (review == null) return true;
    return review.displayText.trim().isEmpty;
  }

  String get _directorTitle {
    final shopName =
        store.shop.name.trim().isEmpty ? 'SORI' : store.shop.name.trim();
    final owner = (store.shop.ownerName ?? '').trim();
    if (owner.isEmpty) return '$shopName 원장';
    final label = owner.contains('원장') ? owner : '$owner 원장';
    return '$shopName $label';
  }

  String get _bio {
    final tip = store.todayHomecareTip.trim();
    if (tip.isNotEmpty) return tip;
    return '아티스트의 샵과 가깝게 소통하고, 지금 시점을 손가락 온기로 채워 주세요';
  }

  void _toggleFollow() {
    final nowFollowing = store.toggleFollowShop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nowFollowing ? '단골 팬으로 등록했어요' : '단골 팬 등록을 해제했어요',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: SoriTokens.primary,
      ),
    );
  }

  void _openReels(int index) {
    final items = _baCases;
    if (items.isEmpty) return;
    pushRootRoute<void>(
      context,
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (_, _, _) => BaReelsDetailPage(
          store: store,
          items: items,
          initialIndex: index.clamp(0, items.length - 1),
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  List<_MomentTile> get _moments {
    final slides = store.gallerySlides;
    final out = <_MomentTile>[];
    for (var i = 0; i < slides.length; i++) {
      final s = slides[i];
      out.add(
        _MomentTile(
          id: s.id,
          title: s.title,
          imageUrl:
              'https://picsum.photos/seed/sori-moment-${s.id}/600/600',
          kind: s.kind,
        ),
      );
    }
    // 매거진 밀도 보강 (데모)
    const extras = [
      ('m-shop', '샵 전경'),
      ('m-bed', '케어룸'),
      ('m-tool', '디바이스'),
      ('m-tea', '티타임'),
      ('m-light', '조명'),
      ('m-flower', '플라워'),
    ];
    for (final e in extras) {
      if (out.any((t) => t.id == e.$1)) continue;
      out.add(
        _MomentTile(
          id: e.$1,
          title: e.$2,
          imageUrl: 'https://picsum.photos/seed/sori-${e.$1}/600/600',
        ),
      );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (store.session?.activeMode == UserRole.director) {
      return const SizedBox.shrink();
    }

    final following = store.isFollowingShop();
    final baCount = _baCases.length;
    final followers = store.shopFollowerCount;
    final highlights = store.shopHighlights.isNotEmpty
        ? store.shopHighlights
        : const <ShopHighlight>[];

    return ColoredBox(
      color: SoriTokens.background,
      child: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              // 상단 타이틀
              SliverAppBar(
                pinned: true,
                floating: false,
                backgroundColor: SoriTokens.background,
                foregroundColor: SoriTokens.textPrimary,
                elevation: 0,
                scrolledUnderElevation: 0.5,
                title: Text(
                  store.shop.name.trim().isEmpty
                      ? 'SORI'
                      : store.shop.name.trim(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: SoriTokens.textPrimary,
                  ),
                ),
                actions: [
                  if (_needsReviewCta)
                    TextButton(
                      onPressed: () => widget.onSelectTab?.call(2),
                      child: const Text(
                        'AI 후기',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: SoriTokens.primary,
                        ),
                      ),
                    ),
                ],
              ),
              // 프로필 헤더
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  SoriTokens.primary,
                                  SoriTokens.primaryLight,
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: SoriTokens.primary
                                      .withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(18),
                              child: SoriLogo(width: 50, height: 50),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _StatColumn(
                                    value: '$baCount',
                                    label: 'B/A 게시물',
                                  ),
                                ),
                                Expanded(
                                  child: _StatColumn(
                                    value: _formatCount(followers),
                                    label: '단골 팬',
                                  ),
                                ),
                                Expanded(
                                  child: _StatColumn(
                                    value: '${highlights.length}',
                                    label: '하이라이트',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _directorTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: SoriTokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _bio,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: SoriTokens.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 42,
                        child: FilledButton.icon(
                          onPressed: _toggleFollow,
                          style: FilledButton.styleFrom(
                            backgroundColor: following
                                ? SoriTokens.surfaceElevated
                                : SoriTokens.primary,
                            foregroundColor: following
                                ? SoriTokens.textPrimary
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: Icon(
                            following
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 18,
                          ),
                          label: Text(
                            following ? '단골 팬 · 팔로잉' : '♡ 단골 팬 등록',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 98,
                        child: highlights.isEmpty
                            ? ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: 4,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, i) {
                                  const titles = [
                                    '장벽케어',
                                    '리프팅',
                                    '바디',
                                    '일상',
                                  ];
                                  return _HighlightRing(
                                    title: titles[i],
                                    imageUrl:
                                        'https://picsum.photos/seed/sori-hl-fallback-$i/200/200',
                                  );
                                },
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: highlights.length,
                                itemBuilder: (context, index) {
                                  final h = highlights[index];
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      right: index == highlights.length - 1
                                          ? 0
                                          : 12,
                                    ),
                                    child: _HighlightRing(
                                      title: h.title,
                                      imageUrl: h.coverImageUrl,
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              // 탭바
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarHeaderDelegate(
                  tabBar: TabBar(
                    controller: _tabController,
                    labelColor: SoriTokens.primary,
                    unselectedLabelColor: SoriTokens.textSecondary,
                    indicatorColor: SoriTokens.primary,
                    indicatorWeight: 2.5,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                    tabs: const [
                      Tab(text: '🖼️ B/A 케이스 피드'),
                      Tab(text: '🌿 샵 모먼트'),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _BaCaseGridTab(
                items: _baCases,
                onOpen: _openReels,
              ),
              _ShopMomentsGridTab(moments: _moments),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}만';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}천';
    return '$n';
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: SoriTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: SoriTokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _HighlightRing extends StatelessWidget {
  const _HighlightRing({
    required this.title,
    this.imageUrl,
  });

  final String title;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    return SizedBox(
      width: 76,
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF58529),
                  Color(0xFFDD2A7B),
                  Color(0xFF8134AF),
                ],
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: url.isEmpty
                  ? const ColoredBox(
                      color: SoriTokens.primarySoft,
                      child: Icon(Icons.auto_awesome, color: SoriTokens.primary),
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.low,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: SoriTokens.primarySoft,
                        child: Icon(
                          Icons.auto_awesome,
                          color: SoriTokens.primary,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: SoriTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  _TabBarHeaderDelegate({required this.tabBar});

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: SoriTokens.background,
      elevation: overlapsContent ? 1 : 0,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}

class _BaCaseGridTab extends StatelessWidget {
  const _BaCaseGridTab({
    required this.items,
    required this.onOpen,
  });

  final List<CommunityCaseItem> items;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  '등록된 B/A 케이스를 준비 중입니다 ✨',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: SoriTokens.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 88),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: 0.78,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = items[index];
                final chart = item.chart;
                final after = chart.afterImageUrl?.trim() ?? '';
                final before = chart.beforeImageUrl?.trim() ?? '';
                final url = after.isNotEmpty ? after : before;
                final tag = chart.concernChips.isNotEmpty
                    ? '#${chart.concernChips.first}'
                    : (chart.careName.trim().isNotEmpty
                        ? '#${chart.careName.trim()}'
                        : '#케어');
                return _BaGridTile(
                  imageUrl: url,
                  tag: tag,
                  onTap: () => onOpen(index),
                );
              },
              childCount: items.length,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _BaGridTile extends StatelessWidget {
  const _BaGridTile({
    required this.imageUrl,
    required this.tag,
    required this.onTap,
  });

  final String imageUrl;
  final String tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoriTokens.surfaceElevated,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.low,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: SoriTokens.surface,
                  child: Icon(Icons.image_outlined, color: SoriTokens.textSecondary),
                ),
              )
            else
              const ColoredBox(
                color: SoriTokens.surface,
                child: Icon(Icons.image_outlined, color: SoriTokens.textSecondary),
              ),
            Positioned(
              left: 8,
              bottom: 8,
              right: 8,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    tag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
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

class _MomentTile {
  const _MomentTile({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.kind,
  });

  final String id;
  final String title;
  final String imageUrl;
  final GalleryKind? kind;
}

class _ShopMomentsGridTab extends StatelessWidget {
  const _ShopMomentsGridTab({required this.moments});

  final List<_MomentTile> moments;

  @override
  Widget build(BuildContext context) {
    if (moments.isEmpty) {
      return const CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                '샵 모먼트가 곧 올라올 예정이에요',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: SoriTokens.textSecondary,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 88),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: 1,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final m = moments[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      m.imageUrl,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.low,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: SoriTokens.primarySoft,
                        child: Center(
                          child: Text(
                            m.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: SoriTokens.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 4,
                      bottom: 4,
                      right: 4,
                      child: Text(
                        m.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.7),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
              childCount: moments.length,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
            ),
          ),
        ),
      ],
    );
  }
}
