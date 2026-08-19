import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/community_case_item.dart';
import '../models/customer_chart.dart';
import '../models/session_user.dart';
import '../models/shop.dart';
import '../routing/sori_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/case_timeline_modal.dart';
import '../widgets/home_feed_card.dart';
import '../widgets/sori_logo.dart';
import 'ba_reels_detail_page.dart';

/// 원장·고객 공통 통합 커뮤니티 홈 피드 (스토리 링 + 세로 무한 피드).
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

class _UnifiedHomeFeedPageState extends State<UnifiedHomeFeedPage> {
  static const _viewedStoriesPrefsKey = 'sori_story_ring_viewed_v1';

  final _liked = <String>{};
  final _bookmarked = <String>{};
  final _likeCounts = <String, int>{};
  final _comments = <String, List<_FeedComment>>{};

  /// shopId → 열람 시각(ms). 이후 생성된 스토리만 Active.
  final Map<String, int> _storyViewedAtMs = {};
  int _visibleCount = 10;

  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshCommunityHotCases();
      store.refreshShopFandomMeta();
      _loadViewedStories();
    });
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Future<void> _loadViewedStories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_viewedStoriesPrefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final next = <String, int>{};
      for (final e in decoded.entries) {
        final id = e.key.toString();
        final v = e.value;
        if (v is int) {
          next[id] = v;
        } else if (v is num) {
          next[id] = v.toInt();
        }
      }
      if (!mounted) return;
      setState(() {
        _storyViewedAtMs
          ..clear()
          ..addAll(next);
      });
    } catch (_) {}
  }

  Future<void> _persistViewedStories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _viewedStoriesPrefsKey,
        jsonEncode(_storyViewedAtMs),
      );
    } catch (_) {}
  }

  List<CommunityCaseItem> get _feed {
    final hot = store.communityHotCases;
    return hot.isNotEmpty ? hot : store.favoriteShopCaseItems();
  }

  DateTime? _latestStoryAtForShop(String shopId) {
    DateTime? latest;
    void consider(DateTime? dt) {
      if (dt == null) return;
      if (latest == null || dt.isAfter(latest!)) latest = dt;
    }

    if (shopId == store.shop.id) {
      for (final h in store.shopHighlights) {
        consider(h.createdAt);
      }
    }
    for (final item in _feed) {
      if (item.shop.id != shopId && item.chart.shopId != shopId) continue;
      consider(item.chart.createdAt ?? item.chart.visitCheckedAt);
    }
    return latest;
  }

  bool _hasNewStory(String shopId) {
    final latest = _latestStoryAtForShop(shopId);
    if (latest == null) return false;
    final age = DateTime.now().difference(latest);
    if (age > const Duration(hours: 24) || age.isNegative) return false;
    final viewedMs = _storyViewedAtMs[shopId];
    if (viewedMs == null) return true;
    return latest.millisecondsSinceEpoch > viewedMs;
  }

  List<_StoryShop> get _storyShops {
    final byId = <String, _StoryShop>{};
    void addShop(Shop shop) {
      final id = shop.id.trim().isEmpty ? shop.name : shop.id;
      byId.putIfAbsent(
        id,
        () => _StoryShop(
          shop: shop,
          hasNewStory: _hasNewStory(id),
        ),
      );
    }

    addShop(store.shop);
    for (final item in store.communityHotCases) {
      addShop(item.shop);
    }
    for (final id in store.followedShopIds) {
      if (id == store.shop.id) continue;
      byId.putIfAbsent(
        id,
        () => _StoryShop(
          shop: Shop(
            id: id,
            name: '단골 샵',
            naverPlaceUrl: '',
          ),
          hasNewStory: _hasNewStory(id),
        ),
      );
    }
    return byId.values.toList();
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

  void _toggleBookmark(String chartId) {
    setState(() {
      if (!_bookmarked.remove(chartId)) _bookmarked.add(chartId);
    });
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
      isScrollControlled: true,
      backgroundColor: Colors.white,
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

  void _openReels(int index) {
    final items = _feed;
    if (items.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => BaReelsDetailPage(
          store: store,
          items: items,
          initialIndex: index.clamp(0, items.length - 1),
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _openCaseTimeline(CommunityCaseItem item, int feedIndex) async {
    final care = item.chart.careName.trim().isNotEmpty
        ? item.chart.careName.trim()
        : '관리 케이스';
    await CaseTimelineModal.show(
      context,
      store: store,
      chartId: item.chart.id,
      careLabel: care,
      onOpenFullScreen: () => _openReels(feedIndex),
    );
  }

  Future<void> _requestSeminar(CommunityCaseItem item) async {
    final myShopId = store.shop.id.trim();
    if (myShopId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('샵 정보가 없어 요청할 수 없습니다.')),
      );
      return;
    }
    if (item.shop.id == myShopId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내 샵 케이스에는 세미나 요청이 필요 없습니다.')),
      );
      return;
    }

    final ok = await store.requestSeminar(
      caseId: item.chart.id,
      requestorShopId: myShopId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? '🎓 세미나 요청이 전달됐어요' : '요청에 실패했습니다. 다시 시도해 주세요.',
        ),
        backgroundColor: ok ? SoriTokens.primary : Colors.redAccent,
      ),
    );
  }

  bool get _isDirectorB2B =>
      store.session?.activeMode == UserRole.director;

  Future<void> _markStoryViewed(String shopId) async {
    final id = shopId.trim();
    if (id.isEmpty) return;
    setState(() {
      _storyViewedAtMs[id] = DateTime.now().millisecondsSinceEpoch;
    });
    await _persistViewedStories();
  }

  Future<void> _openStory(_StoryShop story) async {
    final shop = story.shop;
    final highlights = shop.id == store.shop.id
        ? store.shopHighlights
        : const [];
    final cases = _feed
        .where((e) => e.shop.id == shop.id || e.chart.shopId == shop.id)
        .take(3)
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        shop.name.trim().isEmpty ? '샵 스토리' : shop.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (highlights.isNotEmpty)
                  ...highlights.take(4).map(
                        (h) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '✨ ${h.title}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                else if (cases.isNotEmpty)
                  ...cases.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '📸 ${c.chart.careName.trim().isEmpty ? '관리 케이스' : c.chart.careName}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                else
                  const Text(
                    '최근 24시간 내 새 소식이 곧 올라올 예정이에요.',
                    style: TextStyle(color: Colors.white70),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openShopProfile(shop);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: SoriTokens.primary,
                    ),
                    child: const Text('샵 프로필 보기'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    await _markStoryViewed(shop.id);
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              CircleAvatar(
                radius: 36,
                backgroundColor: SoriTokens.primarySoft,
                backgroundImage: avatar.isNotEmpty && !avatar.startsWith('data:')
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
                ),
              ),
              if ((shop.ownerName ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '원장 ${shop.ownerName}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  bio,
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.4, fontWeight: FontWeight.w500),
                ),
              ],
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

  @override
  Widget build(BuildContext context) {
    final feed = _feed;
    final shown = feed.take(_visibleCount).toList();
    final stories = _storyShops;
    final loading = store.communityHotCasesLoading && feed.isEmpty;

    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels >= n.metrics.maxScrollExtent - 160) {
              if (_visibleCount < feed.length) {
                setState(() {
                  _visibleCount = (_visibleCount + 8).clamp(0, feed.length);
                });
              }
            }
            return false;
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 112,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    scrollDirection: Axis.horizontal,
                    itemCount: stories.isEmpty ? 1 : stories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      if (stories.isEmpty) {
                        final shop = store.shop;
                        return _StoryRing(
                          title: shop.name.trim().isEmpty ? '내 샵' : shop.name,
                          imageUrl: shop.profileImageUrl,
                          hasNewStory: _hasNewStory(shop.id),
                          onTap: () => _openStory(
                            _StoryShop(
                              shop: shop,
                              hasNewStory: _hasNewStory(shop.id),
                            ),
                          ),
                        );
                      }
                      final s = stories[index];
                      return _StoryRing(
                        title: s.shop.name.trim().isEmpty ? '샵' : s.shop.name,
                        imageUrl: s.shop.profileImageUrl,
                        hasNewStory: s.hasNewStory,
                        onTap: () => _openStory(s),
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: Divider(height: 1, thickness: 0.6),
              ),
              if (loading)
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
                        '아직 공유된 B/A 피드가 없어요.\n곧 다양한 후기와 케이스가 올라올 예정이에요.',
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
                  padding: const EdgeInsets.only(bottom: 88),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = shown[index];
                        final id = item.chart.id;
                        final likes =
                            _likeCounts[id] ?? (5 + id.hashCode.abs() % 48);
                        final comments =
                            _comments[id] ?? const <_FeedComment>[];
                        return HomeFeedCard(
                          item: item,
                          currentUserId: store.session?.id,
                          review: item.review ??
                              store.reviewForChart(item.chart.id),
                          liked: _liked.contains(id),
                          likeCount: likes,
                          commentCount: comments.length,
                          bookmarked: _bookmarked.contains(id),
                          showSeminarRequest: _isDirectorB2B &&
                              item.shop.id != store.shop.id,
                          showDivider: index < shown.length - 1,
                          onLike: () => _toggleLike(id),
                          onComment: () => _openComments(item.chart),
                          onBookmark: () => _toggleBookmark(id),
                          onOpenMedia: () => _openCaseTimeline(item, index),
                          onOpenFullScreen: () => _openReels(index),
                          onSeminarRequest: () => _requestSeminar(item),
                          onBookingCta: () =>
                              _openNaverBookingOrProfile(item.shop),
                          onShopProfile: () => _openShopProfile(item.shop),
                        );
                      },
                      childCount: shown.length,
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: true,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryShop {
  const _StoryShop({required this.shop, required this.hasNewStory});

  final Shop shop;
  final bool hasNewStory;
}

class _StoryRing extends StatefulWidget {
  const _StoryRing({
    required this.title,
    required this.hasNewStory,
    required this.onTap,
    this.imageUrl,
  });

  final String title;
  final String? imageUrl;
  final bool hasNewStory;
  final VoidCallback onTap;

  @override
  State<_StoryRing> createState() => _StoryRingState();
}

class _StoryRingState extends State<_StoryRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.hasNewStory) {
      _spin.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _StoryRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasNewStory && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.hasNewStory && _spin.isAnimating) {
      _spin.stop();
      _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.imageUrl?.trim() ?? '';
    final active = widget.hasNewStory;

    return SizedBox(
      width: 74,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            SizedBox(
              width: 68,
              height: 68,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedBuilder(
                    animation: _spin,
                    builder: (context, child) {
                      return Container(
                        width: 68,
                        height: 68,
                        padding: EdgeInsets.all(active ? 2.8 : 1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: active
                              ? SweepGradient(
                                  transform: GradientRotation(
                                    _spin.value * 6.28318530718,
                                  ),
                                  colors: const [
                                    Color(0xFFF58529),
                                    Color(0xFFDD2A7B),
                                    Color(0xFF8134AF),
                                    Color(0xFF515BD4),
                                    Color(0xFFF58529),
                                  ],
                                )
                              : null,
                          border: active
                              ? null
                              : Border.all(
                                  color: const Color(0xFFD1D5DB),
                                  width: 1.5,
                                ),
                          color: active ? null : Colors.transparent,
                        ),
                        child: child,
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white, width: 2.5),
                        image: url.isNotEmpty && !url.startsWith('data:')
                            ? DecorationImage(
                                image: NetworkImage(url),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: url.isEmpty || url.startsWith('data:')
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SoriLogo(width: 36, height: 36),
                            )
                          : null,
                    ),
                  ),
                  if (active)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Text(
                          'N',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.title,
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
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '댓글',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            Expanded(
              child: widget.comments.isEmpty
                  ? Center(
                      child: Text(
                        '첫 댓글을 남겨 보세요',
                        style: TextStyle(color: Colors.grey[500]),
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
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: '댓글 입력',
                        filled: true,
                        fillColor: const Color(0xFFF5F6F8),
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
