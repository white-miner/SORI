import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/community_case_item.dart';
import '../models/community_post.dart';
import '../models/shop.dart';
import '../models/subscription.dart';
import '../pages/case_detail_page.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/home_explore_search.dart';
import '../widgets/official_badge.dart';
import '../widgets/sori_network_image.dart';
import 'community_discover_pane.dart';
import 'device_review_detail_page.dart';
import 'explore_community_post_page.dart';

/// 홈 · 탐색 — B/A 3열 + 원장 스트립 / 검색 시 게시물·프로필.
class HomeExploreTab extends StatefulWidget {
  const HomeExploreTab({super.key, required this.store});

  final SoriStore store;

  @override
  State<HomeExploreTab> createState() => _HomeExploreTabState();
}

enum _SearchSegment { posts, profiles }

class _HomeExploreTabState extends State<HomeExploreTab>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  final _liked = <String>{};
  final _likeCounts = <String, int>{};
  Timer? _debounce;
  String _query = '';
  _SearchSegment _segment = _SearchSegment.posts;
  bool _showAllProfiles = false;

  @override
  bool get wantKeepAlive => true;

  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshCommunityHotCases();
      store.refreshCommunityPosts();
      store.refreshDiscoverDirectors(soft: true);
      store.refreshCaseBookmarks();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    store.removeListener(_onStore);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  bool get _searching => _query.trim().isNotEmpty;

  void _onQueryChanged(String value) {
    setState(() {
      _query = value;
      if (value.trim().isEmpty) {
        _showAllProfiles = false;
      }
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      final q = _query.trim();
      if (q.isNotEmpty) {
        unawaited(store.refreshDiscoverDirectors(query: q));
      } else {
        unawaited(store.refreshDiscoverDirectors(query: ''));
      }
    });
  }

  Set<String> get _linkedChartIds {
    return {
      for (final p in store.communityPosts)
        if (p.postType == CommunityPostType.caseShare &&
            (p.sourceChartId?.trim().isNotEmpty ?? false))
          p.sourceChartId!.trim(),
    };
  }

  List<_GridCell> get _gridCells {
    final linked = _linkedChartIds;
    final cells = <_GridCell>[];

    for (final p in store.communityPosts) {
      if (p.postType != CommunityPostType.caseShare || p.isWhisper) continue;
      final img = p.primaryImageUrl ?? '';
      if (img.isEmpty) continue;
      cells.add(_GridCell.post(p));
    }

    for (final item in store.communityHotCases) {
      if (linked.contains(item.chart.id)) continue;
      final img = (item.chart.afterImageUrl ?? item.chart.beforeImageUrl ?? '')
          .trim();
      if (img.isEmpty) continue;
      cells.add(_GridCell.ba(item));
    }
    return cells;
  }

  List<({CommunityCaseItem item, int score})> get _matchedCases {
    final tokens = HomeExploreSearch.tokens(_query);
    final out = <({CommunityCaseItem item, int score})>[];
    for (final item in store.communityHotCases) {
      final s = HomeExploreSearch.scoreCase(item, tokens);
      if (s >= 0) out.add((item: item, score: s));
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    return out;
  }

  List<({CommunityPost post, int score})> get _matchedPosts {
    final tokens = HomeExploreSearch.tokens(_query);
    final out = <({CommunityPost post, int score})>[];
    for (final p in store.communityPosts) {
      if (!HomeExploreSearch.isSearchablePost(p)) continue;
      // caseShare는 B/A 결과와 중복될 수 있어 검색 게시물에서는 인테리어·기기만.
      if (p.postType == CommunityPostType.caseShare) continue;
      final s = HomeExploreSearch.scorePost(p, tokens);
      if (s >= 0) out.add((post: p, score: s));
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    return out;
  }

  List<DiscoverDirector> get _matchedDirectors {
    final tokens = HomeExploreSearch.tokens(_query);
    if (tokens.isEmpty) return store.discoverDirectors;
    final scored = <({DiscoverDirector d, int score})>[];
    for (final d in store.discoverDirectors) {
      final s = HomeExploreSearch.scoreDirector(d, tokens);
      if (s >= 0) scored.add((d: d, score: s));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((e) => e.d).toList();
  }

  List<DiscoverDirector> get _stripDirectors {
    final followed = store.discoverDirectors
        .where((d) => store.isFollowingShop(d.shopId))
        .toList();
    if (followed.isNotEmpty) return followed.take(12).toList();
    return store.discoverDirectors.take(12).toList();
  }

  void _toggleLike(String id) {
    setState(() {
      if (_liked.remove(id)) {
        _likeCounts[id] = ((_likeCounts[id] ?? 1) - 1).clamp(0, 9999);
      } else {
        _liked.add(id);
        _likeCounts[id] = (_likeCounts[id] ?? 0) + 1;
      }
    });
  }

  Future<void> _toggleBookmark(String id) async {
    try {
      await store.toggleCaseBookmark(id);
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

  void _openCaseDetail(CommunityCaseItem item) {
    final id = item.chart.id;
    CaseDetailPage.push(
      context,
      page: CaseDetailPage(
        item: item,
        review: item.review ?? store.reviewForChart(item.chart.id),
        currentUserId: store.session?.id,
        liked: _liked.contains(id),
        likeCount: _likeCounts[id] ?? (3 + id.hashCode.abs() % 40),
        commentCount: 0,
        bookmarked: store.isChartBookmarked(id),
        onLike: () => _toggleLike(id),
        onBookmark: () => _toggleBookmark(id),
        onShopProfile: () => _openShopProfile(item.shop),
        onBookingCta: () => _openNaverBooking(item.shop),
        onOpenCommunitySeminar: () {
          store.pendingCommunitySegment = 5;
          final shell = StatefulNavigationShell.maybeOf(context);
          shell?.goBranch(3);
        },
      ),
    );
  }

  Future<void> _openNaverBooking(Shop shop) async {
    final url = shop.naverBookingOrPlaceUrl;
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openShopProfile(Shop shop) async {
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
                decoration: BoxDecoration(
                  color: SoriTokens.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              CircleAvatar(
                radius: 36,
                backgroundColor: SoriTokens.primarySoft,
                backgroundImage:
                    avatar.isNotEmpty && !avatar.startsWith('data:')
                        ? NetworkImage(avatar)
                        : null,
                child: avatar.isEmpty || avatar.startsWith('data:')
                    ? const Icon(Icons.storefront, size: 32)
                    : null,
              ),
              const SizedBox(height: 12),
              ShopNameWithOfficialBadge(
                name: shop.name.trim().isEmpty ? 'SORI' : shop.name,
                isOfficial: shop.displayIsOfficial,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  bio,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: SoriTokens.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _openCommunityPost(CommunityPost post) {
    if (post.postType == CommunityPostType.deviceReview) {
      DeviceReviewDetailPage.open(context, store: store, post: post);
      return;
    }
    ExploreCommunityPostPage.open(context, store: store, post: post);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: SoriTokens.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onQueryChanged,
              style: const TextStyle(color: SoriTokens.textPrimary),
              decoration: InputDecoration(
                hintText: '케어·기기·샵·원장 검색',
                hintStyle: const TextStyle(color: SoriTokens.textSecondary),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: SoriTokens.textSecondary,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onQueryChanged('');
                        },
                      ),
                filled: true,
                fillColor: SoriTokens.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
            ),
          ),
          if (_searching) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  _SegmentChip(
                    label: '게시물',
                    active: _segment == _SearchSegment.posts,
                    onTap: () =>
                        setState(() => _segment = _SearchSegment.posts),
                  ),
                  const SizedBox(width: 8),
                  _SegmentChip(
                    label: '프로필',
                    active: _segment == _SearchSegment.profiles,
                    onTap: () =>
                        setState(() => _segment = _SearchSegment.profiles),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: RefreshIndicator(
              color: SoriTokens.primary,
              onRefresh: () async {
                await Future.wait([
                  store.refreshCommunityHotCases(),
                  store.refreshCommunityPosts(),
                  store.refreshDiscoverDirectors(query: _query.trim()),
                ]);
              },
              child: _searching
                  ? (_segment == _SearchSegment.posts
                      ? _buildPostsResults(bottomInset)
                      : _buildProfileResults(bottomInset))
                  : (_showAllProfiles
                      ? _buildAllProfiles(bottomInset)
                      : _buildBrowse(bottomInset)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowse(double bottomInset) {
    final cells = _gridCells;
    final strip = _stripDirectors;
    final loading = store.communityHotCasesLoading && cells.isEmpty;

    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: SoriTokens.primary),
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        if (strip.isNotEmpty)
          SliverToBoxAdapter(
            child: _DirectorStrip(
              directors: strip,
              onOpenAll: () => setState(() => _showAllProfiles = true),
            ),
          ),
        if (cells.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                '아직 공개된 B/A가 없어요',
                style: TextStyle(
                  color: SoriTokens.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(2, 4, 2, 100 + bottomInset),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                childAspectRatio: 0.78,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final cell = cells[i];
                  return _BaThumbTile(
                    imageUrl: cell.imageUrl,
                    label: cell.label,
                    onTap: () {
                      if (cell.caseItem != null) {
                        _openCaseDetail(cell.caseItem!);
                      } else if (cell.post != null) {
                        _openCommunityPost(cell.post!);
                      }
                    },
                  );
                },
                childCount: cells.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAllProfiles(double bottomInset) {
    final rows = store.discoverDirectors;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(0, 0, 0, 100 + bottomInset),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _showAllProfiles = false),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const Text(
                '원장',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (store.discoverDirectorsLoading && rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
          )
        else if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text(
                '아직 추천 원장이 없어요',
                style: TextStyle(color: SoriTokens.textSecondary),
              ),
            ),
          )
        else
          for (final d in rows)
            DiscoverDirectorRow(
              director: d,
              following: store.isFollowingShop(d.shopId),
              onToggle: () => store.toggleDiscoverFollow(d),
            ),
      ],
    );
  }

  Widget _buildPostsResults(double bottomInset) {
    final cases = _matchedCases;
    final posts = _matchedPosts;
    final empty = cases.isEmpty && posts.isEmpty;

    if (empty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(24, 48, 24, 100 + bottomInset),
        children: const [
          Text(
            '게시물 결과가 없어요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: SoriTokens.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '프로필 탭에서 원장·샵을 찾아보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SoriTokens.textSecondary),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 4, 16, 100 + bottomInset),
      children: [
        for (final row in cases) ...[
          _ExploreBaPostCard(
            item: row.item,
            onOpen: () => _openCaseDetail(row.item),
            onMore: () => _openCaseDetail(row.item),
          ),
          const SizedBox(height: 14),
        ],
        for (final row in posts) ...[
          _ExploreCommunityPostCard(
            post: row.post,
            onOpen: () => _openCommunityPost(row.post),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildProfileResults(double bottomInset) {
    final rows = _matchedDirectors;
    if (store.discoverDirectorsLoading && rows.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.2),
      );
    }
    if (rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(24, 48, 24, 100 + bottomInset),
        children: const [
          Text(
            '프로필 결과가 없어요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: SoriTokens.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '게시물 탭에서 관련 콘텐츠를 확인해 보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SoriTokens.textSecondary),
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(0, 4, 0, 100 + bottomInset),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final d = rows[i];
        return DiscoverDirectorRow(
          director: d,
          following: store.isFollowingShop(d.shopId),
          onToggle: () => store.toggleDiscoverFollow(d),
        );
      },
    );
  }
}

class _GridCell {
  const _GridCell._({this.caseItem, this.post});

  factory _GridCell.ba(CommunityCaseItem item) => _GridCell._(caseItem: item);
  factory _GridCell.post(CommunityPost post) => _GridCell._(post: post);

  final CommunityCaseItem? caseItem;
  final CommunityPost? post;

  String get imageUrl {
    if (caseItem != null) {
      return (caseItem!.chart.afterImageUrl ??
              caseItem!.chart.beforeImageUrl ??
              '')
          .trim();
    }
    return post?.primaryImageUrl ?? '';
  }

  String get label {
    if (caseItem != null) {
      final n = caseItem!.chart.careName.trim();
      return n.isEmpty ? 'B/A' : n;
    }
    final t = post?.title.trim() ?? '';
    return t.isEmpty ? '케이스' : t;
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? SoriTokens.primarySoft : SoriTokens.surfaceOverlay,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? SoriTokens.primary : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: active ? SoriTokens.primary : SoriTokens.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DirectorStrip extends StatelessWidget {
  const _DirectorStrip({
    required this.directors,
    required this.onOpenAll,
  });

  final List<DiscoverDirector> directors;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '원장',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: SoriTokens.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: onOpenAll,
                child: const Text(
                  '전체',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 86,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: directors.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final d = directors[i];
              return SizedBox(
                width: 64,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: SoriTokens.surfaceOverlay,
                      backgroundImage: d.avatarUrl.isNotEmpty
                          ? NetworkImage(d.avatarUrl)
                          : null,
                      child: d.avatarUrl.isEmpty
                          ? Text(
                              d.nickname.characters.first,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      d.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _BaThumbTile extends StatelessWidget {
  const _BaThumbTile({
    required this.imageUrl,
    required this.label,
    required this.onTap,
  });

  final String imageUrl;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoriTokens.surfaceOverlay,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              SoriNetworkImage(url: imageUrl, fit: BoxFit.cover)
            else
              const ColoredBox(color: SoriTokens.surfaceOverlay),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 18, 6, 6),
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
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

class _ExploreBaPostCard extends StatelessWidget {
  const _ExploreBaPostCard({
    required this.item,
    required this.onOpen,
    required this.onMore,
  });

  final CommunityCaseItem item;
  final VoidCallback onOpen;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final after = (item.chart.afterImageUrl ?? '').trim();
    final before = (item.chart.beforeImageUrl ?? '').trim();
    final cover = after.isNotEmpty ? after : before;
    final title = item.chart.careName.trim().isEmpty
        ? '관리 케이스'
        : item.chart.careName.trim();

    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: SoriTokens.primarySoft,
                    backgroundImage: item.displayAuthorAvatarUrl.isNotEmpty
                        ? NetworkImage(item.displayAuthorAvatarUrl)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayAuthorNickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                        Text(
                          item.displayShopAffiliation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: SoriTokens.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: SoriTokens.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'B/A',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: SoriTokens.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: 4 / 5,
              child: cover.isEmpty
                  ? const ColoredBox(color: SoriTokens.surfaceOverlay)
                  : SoriNetworkImage(url: cover, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.personaLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onMore,
                      child: const Text(
                        '더보기',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
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

class _ExploreCommunityPostCard extends StatelessWidget {
  const _ExploreCommunityPostCard({
    required this.post,
    required this.onOpen,
  });

  final CommunityPost post;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cover = post.primaryImageUrl ?? '';
    final title =
        post.title.trim().isEmpty ? post.postType.label : post.title.trim();

    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: SoriTokens.primarySoft,
                    backgroundImage:
                        (post.shopAvatarUrl?.trim().isNotEmpty ?? false)
                            ? NetworkImage(post.shopAvatarUrl!.trim())
                            : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      post.authorDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  Text(
                    post.postType.label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: SoriTokens.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (cover.isNotEmpty)
              AspectRatio(
                aspectRatio: 4 / 3,
                child: SoriNetworkImage(url: cover, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  if (post.body.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      post.body.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onOpen,
                      child: const Text(
                        '더보기',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
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
