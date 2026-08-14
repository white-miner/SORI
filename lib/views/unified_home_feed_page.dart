import 'package:flutter/material.dart';

import '../models/community_case_item.dart';
import '../models/customer_chart.dart';
import '../models/customer_review.dart';
import '../models/session_user.dart';
import '../models/shop.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/before_after_slider.dart';
import '../widgets/case_review_inline.dart';
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
  final _liked = <String>{};
  final _likeCounts = <String, int>{};
  final _comments = <String, List<_FeedComment>>{};
  int _visibleCount = 10;

  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshCommunityHotCases();
      store.refreshShopFandomMeta();
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

  List<CommunityCaseItem> get _feed {
    final hot = store.communityHotCases;
    if (hot.isNotEmpty) return hot;
    return store.favoriteShopCaseItems();
  }

  List<_StoryShop> get _storyShops {
    final byId = <String, _StoryShop>{};
    void addShop(Shop shop, {required bool highlight}) {
      final id = shop.id.trim().isEmpty ? shop.name : shop.id;
      byId.putIfAbsent(
        id,
        () => _StoryShop(
          shop: shop,
          highlight: highlight || store.isFollowingShop(shop.id),
        ),
      );
    }

    addShop(store.shop, highlight: true);
    for (final item in store.communityHotCases) {
      addShop(item.shop, highlight: false);
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
          highlight: true,
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

  void _openComments(CustomerChart chart) {
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

  @override
  Widget build(BuildContext context) {
    final feed = _feed;
    final shown = feed.take(_visibleCount).toList();
    final stories = _storyShops;
    final loading = store.communityHotCasesLoading && feed.isEmpty;

    return ColoredBox(
      color: const Color(0xFFFAFAFA),
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
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 108,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    scrollDirection: Axis.horizontal,
                    itemCount: stories.isEmpty ? 1 : stories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      if (stories.isEmpty) {
                        return _StoryRing(
                          title: store.shop.name.trim().isEmpty
                              ? '내 샵'
                              : store.shop.name,
                          imageUrl: store.shop.profileImageUrl,
                          ring: true,
                        );
                      }
                      final s = stories[index];
                      return _StoryRing(
                        title: s.shop.name.trim().isEmpty
                            ? '샵'
                            : s.shop.name,
                        imageUrl: s.shop.profileImageUrl,
                        ring: true,
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
                        return _FeedPostCard(
                          item: item,
                          review: item.review ??
                              store.reviewForChart(item.chart.id),
                          liked: _liked.contains(id),
                          likeCount: likes,
                          commentCount: comments.length,
                          onLike: () => _toggleLike(id),
                          onComment: () => _openComments(item.chart),
                          onOpenMedia: () => _openReels(index),
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
  const _StoryShop({required this.shop, required this.highlight});

  final Shop shop;
  final bool highlight;
}

class _StoryRing extends StatelessWidget {
  const _StoryRing({
    required this.title,
    required this.ring,
    this.imageUrl,
  });

  final String title;
  final String? imageUrl;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    return SizedBox(
      width: 74,
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: ring
                  ? const LinearGradient(
                      colors: [
                        Color(0xFFF58529),
                        Color(0xFFDD2A7B),
                        Color(0xFF8134AF),
                      ],
                    )
                  : null,
              color: ring ? null : SoriTokens.primarySoft,
            ),
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
          const SizedBox(height: 6),
          Text(
            title,
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
  }
}

class _FeedPostCard extends StatelessWidget {
  const _FeedPostCard({
    required this.item,
    required this.liked,
    required this.likeCount,
    required this.commentCount,
    required this.onLike,
    required this.onComment,
    required this.onOpenMedia,
    this.review,
  });

  final CommunityCaseItem item;
  final CustomerReview? review;
  final bool liked;
  final int likeCount;
  final int commentCount;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onOpenMedia;

  @override
  Widget build(BuildContext context) {
    final shop = item.shop;
    final chart = item.chart;
    final care = chart.careName.trim().isNotEmpty
        ? chart.careName.trim()
        : '관리 케이스';
    final owner = (shop.ownerName ?? '').trim().isEmpty
        ? '원장'
        : shop.ownerName!.trim();
    final hasReview =
        review != null && review!.displayText.trim().isNotEmpty;
    final avatar = shop.profileImageUrl?.trim() ?? '';

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: SoriTokens.primarySoft,
                  backgroundImage: avatar.isNotEmpty && !avatar.startsWith('data:')
                      ? NetworkImage(avatar)
                      : null,
                  child: avatar.isEmpty || avatar.startsWith('data:')
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: SoriLogo(width: 22, height: 22),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name.trim().isEmpty ? 'SORI' : shop.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '원장 $owner · $care',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasReview) const VerifiedReviewBadge(small: true),
              ],
            ),
          ),
          GestureDetector(
            onTap: onOpenMedia,
            child: BeforeAfterSlider(
              height: 320,
              before: ChartImagePane(
                url: chart.beforeImageUrl,
                fallbackLabel: 'Before',
                tone: SoriTokens.primary,
              ),
              after: ChartImagePane(
                url: chart.afterImageUrl,
                fallbackLabel: 'After',
                tone: Colors.green.shade700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: onLike,
                  icon: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? const Color(0xFFE53935) : Colors.grey[800],
                  ),
                ),
                Text(
                  '$likeCount',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onComment,
                  icon: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  '$commentCount',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          if (hasReview)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: CaseReviewInlineBlock(review: review!, compact: true),
            )
          else
            const SizedBox(height: 8),
        ],
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
