import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/community_case_item.dart';
import '../models/customer_chart.dart';
import '../models/session_user.dart';
import '../models/shop.dart';
import '../pages/case_detail_page.dart';
import '../routing/sori_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/home_feed_card.dart';
import '../widgets/sori_logo.dart';

/// 원장·고객 공통 통합 커뮤니티 홈 피드.
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
  final _bookmarked = <String>{};
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
    return hot.isNotEmpty ? hot : store.favoriteShopCaseItems();
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

  void _openCaseDetail(CommunityCaseItem item, int feedIndex) {
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
        bookmarked: _bookmarked.contains(id),
        onLike: () => _toggleLike(id),
        onComment: () => _openComments(item.chart),
        onBookmark: () => _toggleBookmark(id),
        onShopProfile: () => _openShopProfile(item.shop),
        onBookingCta: () => _openNaverBookingOrProfile(item.shop),
        onSeminarRequest: () => _requestSeminar(item),
      ),
    );
  }

  Future<void> _requestSeminar(CommunityCaseItem item) async {
    final session = store.session;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 세미나 요청을 보낼 수 있어요.')),
      );
      return;
    }

    final myShopId = store.shop.id.trim();
    final userId = session.id.trim();
    if (myShopId.isEmpty && userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('요청자 정보가 없어 세미나 요청을 보낼 수 없습니다.')),
      );
      return;
    }

    final ok = await store.requestSeminar(
      caseId: item.chart.id,
      requestorShopId: myShopId.isEmpty ? null : myShopId,
      requestorUserId: userId.isEmpty ? null : userId,
      caseOwnerShopId: item.shop.id,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '해당 케이스의 세미나 개설을 요청했습니다. 원장님이 클래스를 오픈하면 알림을 보내드립니다.'
              : '요청에 실패했습니다. 다시 시도해 주세요.',
        ),
        backgroundColor: ok ? SoriTokens.primary : Colors.redAccent,
      ),
    );
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
    final loading = store.communityHotCasesLoading && feed.isEmpty;

    return ColoredBox(
      color: SoriTokens.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 스크롤 뷰 밖 고정 헤더 — 높이 제약으로 증발 방지
            const Material(
              color: SoriTokens.background,
              child: _HomeInsightStrip(),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.pixels >= n.metrics.maxScrollExtent - 160) {
                    if (_visibleCount < feed.length) {
                      setState(() {
                        _visibleCount =
                            (_visibleCount + 8).clamp(0, feed.length);
                      });
                    }
                  }
                  return false;
                },
                child: CustomScrollView(
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    if (loading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: SoriTokens.primary,
                          ),
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
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 110),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = shown[index];
                              final id = item.chart.id;
                              final likes = _likeCounts[id] ??
                                  (5 + id.hashCode.abs() % 48);
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
                                onLike: () => _toggleLike(id),
                                onComment: () => _openComments(item.chart),
                                onBookmark: () => _toggleBookmark(id),
                                onOpenDetail: () =>
                                    _openCaseDetail(item, index),
                                onSeminarRequest: () => _requestSeminar(item),
                                onBookingCta: () =>
                                    _openNaverBookingOrProfile(item.shop),
                                onShopProfile: () =>
                                    _openShopProfile(item.shop),
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
          ],
        ),
      ),
    );
  }
}

/// 홈 최상단 — AI 브리핑 + 명예의 전당 가로 스크롤.
class _HomeInsightStrip extends StatelessWidget {
  const _HomeInsightStrip();

  static const _hallOfFame = <({String name, String initial, int rank})>[
    (name: '김서연 원장', initial: '김', rank: 1),
    (name: '박지훈 원장', initial: '박', rank: 2),
    (name: '이하늘 원장', initial: '이', rank: 3),
    (name: '최민정 원장', initial: '최', rank: 4),
    (name: '정우성 원장', initial: '정', rank: 5),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      width: double.infinity,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        itemCount: 1 + _hallOfFame.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 0) return const _AiBriefingCard();
          final e = _hallOfFame[index - 1];
          return _HallOfFameAvatar(
            name: e.name,
            initial: e.initial,
            rank: e.rank,
          );
        },
      ),
    );
  }
}

class _AiBriefingCard extends StatelessWidget {
  const _AiBriefingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: SoriTokens.card(radius: 20),
      alignment: Alignment.centerLeft,
      child: const Text(
        '✨ 원장님, 작성 대기 중인 임시 차트가 2건 있습니다. 완성하고 프로 뱃지를 획득하세요!',
        style: TextStyle(
          fontSize: 13,
          height: 1.35,
          fontWeight: FontWeight.w700,
          color: SoriTokens.textPrimary,
        ),
      ),
    );
  }
}

class _HallOfFameAvatar extends StatelessWidget {
  const _HallOfFameAvatar({
    required this.name,
    required this.initial,
    required this.rank,
  });

  final String name;
  final String initial;
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: SoriTokens.card(radius: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CircleAvatar(
                    backgroundColor: SoriTokens.primarySoft,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFFC4B5FD),
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  top: -6,
                  right: -4,
                  child: Text('👑', style: TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$rank위',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: SoriTokens.textPrimary,
              height: 1.1,
            ),
          ),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: SoriTokens.textSecondary,
              height: 1.1,
            ),
          ),
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
