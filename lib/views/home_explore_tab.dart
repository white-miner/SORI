import 'dart:async';

import 'package:flutter/material.dart';

import '../features/habit/explore_habit_rails.dart';
import '../models/recommend_feed_category.dart';
import '../models/subscription.dart';
import '../models/unified_feed_item.dart';
import '../services/sori_store.dart';
import '../services/unified_feed_engine.dart';
import '../theme/sori_tokens.dart';
import '../utils/post_navigation.dart';
import '../utils/home_explore_search.dart';
import '../utils/sori_shell_insets.dart';
import '../widgets/explore/explore_rich_info_card.dart';
import '../widgets/glass/sori_glass_overlay.dart';
import '../widgets/glass/sori_glass_tokens.dart';
import 'community_discover_pane.dart';

/// 홈 · 탐색 — 2열 리치 카드 그리드 + 원장 스트립 / 검색 시 게시물·프로필.
class HomeExploreTab extends StatefulWidget {
  const HomeExploreTab({
    super.key,
    required this.store,
    this.scrollController,
  });

  final SoriStore store;
  final ScrollController? scrollController;

  @override
  State<HomeExploreTab> createState() => _HomeExploreTabState();
}

enum _SearchSegment { posts, profiles }

class _HomeExploreTabState extends State<HomeExploreTab>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  _SearchSegment _segment = _SearchSegment.posts;
  bool _showAllProfiles = false;
  /// null = 전체 (PRD v7.8 C5).
  RecommendFeedCategory? _categoryFilter;

  @override
  bool get wantKeepAlive => true;

  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshUnifiedCommunityFeed();
      store.refreshDiscoverDirectors(soft: true);
      store.refreshCaseBookmarks();
      store.refreshChartLikes();
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


  List<UnifiedFeedItem> get _gridItems {
    final all = UnifiedFeedEngine.exploreGridItems(store);
    if (_categoryFilter == null) return all;
    return all
        .where(
          (e) => RecommendFeedCategory.matchesExploreFilter(e, _categoryFilter),
        )
        .toList(growable: false);
  }

  List<({UnifiedFeedItem item, int score})> get _matchedUnified {
    final tokens = HomeExploreSearch.tokens(_query);
    final out = <({UnifiedFeedItem item, int score})>[];
    for (final item in UnifiedFeedEngine.exploreGridItems(store)) {
      if (!RecommendFeedCategory.matchesExploreFilter(item, _categoryFilter)) {
        continue;
      }
      final s = HomeExploreSearch.scoreUnified(item, tokens);
      if (s >= 0) out.add((item: item, score: s));
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


  void _openDirector(DiscoverDirector director) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: SoriTokens.surfaceOverlay,
              backgroundImage: director.avatarUrl.isNotEmpty
                  ? NetworkImage(director.avatarUrl)
                  : null,
              child: director.avatarUrl.isEmpty
                  ? Text(
                      director.nickname.characters.first,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              director.nickname,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (director.shopName.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                director.shopName,
                style: const TextStyle(color: SoriTokens.textSecondary),
              ),
            ],
            const SizedBox(height: 16),
            DiscoverDirectorRow(
              director: director,
              following: store.isFollowingShop(director.shopId),
              onToggle: () => store.toggleDiscoverFollow(director),
            ),
          ],
        ),
      ),
    );
  }




  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bottomInset = SoriShellInsets.scrollBottomInset(context);
    final scrollActive = widget.scrollController != null;
    final ScrollPhysics? scrollPhysics = scrollActive
        ? null
        : const NeverScrollableScrollPhysics();

    return ColoredBox(
      color: SoriTokens.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SoriGlassOverlay(
              borderRadius: BorderRadius.circular(16),
              tier: SoriGlassTier.l1Surface,
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onQueryChanged,
                style: const TextStyle(color: SoriTokens.textPrimary),
                decoration: InputDecoration(
                  hintText: '제목·본문·샵·원장·해시 검색',
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
                  fillColor: Colors.white.withValues(alpha: 0.55),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: SoriTokens.outlinePurple.withValues(alpha: 0.45),
                    ),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: const Text('전체'),
                    selected: _categoryFilter == null,
                    onSelected: (_) => setState(() => _categoryFilter = null),
                    selectedColor: SoriTokens.primary.withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: _categoryFilter == null
                          ? SoriTokens.primary
                          : SoriTokens.textSecondary,
                    ),
                  ),
                ),
                for (final c in RecommendFeedCategory.exploreCategories)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(c.label),
                      selected: _categoryFilter == c,
                      onSelected: (_) => setState(() {
                        _categoryFilter = _categoryFilter == c ? null : c;
                      }),
                      selectedColor: SoriTokens.primary.withValues(alpha: 0.18),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: _categoryFilter == c
                            ? SoriTokens.primary
                            : SoriTokens.textSecondary,
                      ),
                    ),
                  ),
              ],
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
                  store.refreshUnifiedCommunityFeed(force: true),
                  store.refreshDiscoverDirectors(query: _query.trim()),
                ]);
              },
              child: _searching
                  ? (_segment == _SearchSegment.posts
                      ? _buildPostsResults(bottomInset, scrollPhysics)
                      : _buildProfileResults(bottomInset, scrollPhysics))
                  : (_showAllProfiles
                      ? _buildAllProfiles(bottomInset, scrollPhysics)
                      : _buildBrowse(bottomInset, scrollPhysics)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowse(double bottomInset, ScrollPhysics? scrollPhysics) {
    final items = _gridItems;
    final strip = _stripDirectors;
    final loading = store.unifiedFeedLoading && items.isEmpty;

    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: SoriTokens.primary),
      );
    }

    return CustomScrollView(
        key: const Key('explore-browse-scroll'),
        controller: widget.scrollController,
        physics: scrollPhysics,
        slivers: [
        if (strip.isNotEmpty)
          SliverToBoxAdapter(
            child: _DirectorStrip(
              directors: strip,
              onOpenAll: () => setState(() => _showAllProfiles = true),
              onDirectorTap: _openDirector,
            ),
          ),
        SliverToBoxAdapter(
          child: ExploreHabitRails(store: store),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                _categoryFilter == null
                    ? '아직 탐색할 콘텐츠가 없어요'
                    : '「${_categoryFilter!.label}」에 해당하는 글이 없어요',
                style: const TextStyle(
                  color: SoriTokens.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            key: const Key('explore-browse-list-padding'),
            padding: EdgeInsets.fromLTRB(16, 4, 16, bottomInset),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 4 / 5,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final item = items[i];
                  final imageUrl = UnifiedFeedEngine.gridImageUrl(item);
                  return ExploreRichInfoCard(
                    imageUrl: imageUrl,
                    title: UnifiedFeedEngine.gridTitle(item),
                    subtitle: UnifiedFeedEngine.gridSubtitle(item),
                    authorName: UnifiedFeedEngine.gridAuthorName(item),
                    authorAvatarUrl: UnifiedFeedEngine.gridAuthorAvatar(item),
                    categoryLabel: UnifiedFeedEngine.gridCategoryLabel(item),
                    textOnly: imageUrl.isEmpty,
                    onTap: () => openUnifiedPostOriginal(
                      context,
                      item: item,
                      store: store,
                    ),
                  );
                },
                childCount: items.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAllProfiles(double bottomInset, ScrollPhysics? scrollPhysics) {
    final rows = store.discoverDirectors;
    return ListView(
      controller: widget.scrollController,
      physics: scrollPhysics,
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset),
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

  Widget _buildPostsResults(double bottomInset, ScrollPhysics? scrollPhysics) {
    final matched = _matchedUnified;
    if (matched.isEmpty) {
      return ListView(
        controller: widget.scrollController,
        physics: scrollPhysics,
        padding: EdgeInsets.fromLTRB(24, 48, 24, bottomInset),
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
            '카테고리 칩을 바꾸거나 프로필 탭에서 원장·샵을 찾아보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SoriTokens.textSecondary),
          ),
        ],
      );
    }

    return GridView.builder(
      controller: widget.scrollController,
      physics: scrollPhysics,
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomInset),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 4 / 5,
      ),
      itemCount: matched.length,
      itemBuilder: (context, i) {
        final item = matched[i].item;
        final imageUrl = UnifiedFeedEngine.gridImageUrl(item);
        return ExploreRichInfoCard(
          imageUrl: imageUrl,
          title: UnifiedFeedEngine.gridTitle(item),
          subtitle: UnifiedFeedEngine.gridSubtitle(item),
          authorName: UnifiedFeedEngine.gridAuthorName(item),
          authorAvatarUrl: UnifiedFeedEngine.gridAuthorAvatar(item),
          categoryLabel: UnifiedFeedEngine.gridCategoryLabel(item),
          textOnly: imageUrl.isEmpty,
          onTap: () => openUnifiedPostOriginal(
            context,
            item: item,
            store: store,
          ),
        );
      },
    );
  }

  Widget _buildProfileResults(double bottomInset, ScrollPhysics? scrollPhysics) {
    final rows = _matchedDirectors;
    if (store.discoverDirectorsLoading && rows.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.2),
      );
    }
    if (rows.isEmpty) {
      return ListView(
        controller: widget.scrollController,
        physics: scrollPhysics,
        padding: EdgeInsets.fromLTRB(24, 48, 24, bottomInset),
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
      controller: widget.scrollController,
      physics: scrollPhysics,
      padding: EdgeInsets.fromLTRB(0, 4, 0, bottomInset),
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
        decoration: SoriGlassTokens.pseudoChipDecoration(
          radius: 20,
          active: active,
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
    required this.onDirectorTap,
  });

  final List<DiscoverDirector> directors;
  final VoidCallback onOpenAll;
  final ValueChanged<DiscoverDirector> onDirectorTap;

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
              return GestureDetector(
                onTap: () => onDirectorTap(d),
                child: SizedBox(
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
