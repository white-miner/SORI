import 'package:flutter/material.dart';

import '../models/customer_chart.dart';
import '../models/session_user.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/before_after_slider.dart';
import '../widgets/sori_logo.dart';
import 'director_fandom_profile_page.dart';

/// 고객 모드 전용 홈 — 원장 팬덤 프로필 · B/A 소통 피드 · AI 후기 CTA.
/// 원장 관리 일정/사진 등록 UI는 절대 포함하지 않음.
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

class _CustomerHomePageState extends State<CustomerHomePage> {
  final _liked = <String>{};
  final _likeCounts = <String, int>{};
  final _comments = <String, List<_HomeComment>>{};

  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  List<CustomerChart> get _sharedCases {
    final out = <CustomerChart>[];
    for (final chart in store.charts) {
      if (!chart.caseShared || !chart.isConsentSigned) continue;
      final b = chart.beforeImageUrl?.trim() ?? '';
      final a = chart.afterImageUrl?.trim() ?? '';
      if (b.isEmpty && a.isEmpty) continue;
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
    final shopName = store.shop.name.trim().isEmpty ? 'SORI' : store.shop.name.trim();
    final owner = (store.shop.ownerName ?? '').trim();
    if (owner.isEmpty) return '$shopName 원장';
    final label = owner.contains('원장') ? owner : '$owner 원장';
    return '$shopName $label';
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DirectorFandomProfilePage(store: store),
      ),
    );
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

  void _toggleLike(String chartId) {
    setState(() {
      final base = _likeCounts[chartId] ?? (3 + chartId.hashCode.abs() % 40);
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
        return _HomeCommentSheet(
          comments: list,
          onSubmit: (text) {
            final session = store.session;
            final author = session?.name.trim().isNotEmpty == true
                ? session!.name.trim()
                : '고객';
            setState(() {
              list.add(
                _HomeComment(
                  author: author,
                  body: text,
                  isDirector: session?.activeMode == UserRole.director,
                  at: DateTime.now(),
                ),
              );
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 안전장치: 원장 모드면 빈 자리 (라우터가 교체해야 함)
    if (store.session?.activeMode == UserRole.director) {
      return const SizedBox.shrink();
    }

    final cases = _sharedCases;
    final following = store.isFollowingShop();
    final myCare = _latestMyCare;
    final tip = store.todayHomecareTip.trim().isEmpty
        ? '오늘도 건강한 피부를 선물해 드릴게요'
        : store.todayHomecareTip.trim();

    return ColoredBox(
      color: const Color(0xFFF5F6F8),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // —— 원장 아티스트 프로필 & 샵 모먼트 ——
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openProfile,
                borderRadius: BorderRadius.circular(22),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF8B7CFF),
                        Color(0xFF6C5CE7),
                        Color(0xFF4A3BCF),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 54,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(22),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.28),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      width: 2,
                                    ),
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SoriLogo(width: 40, height: 40),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'ARTIST',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _directorTitle,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          height: 1.25,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        tip,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.92,
                                          ),
                                          fontSize: 12.5,
                                          height: 1.35,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white70,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 44,
                              child: FilledButton.icon(
                                onPressed: _toggleFollow,
                                style: FilledButton.styleFrom(
                                  backgroundColor: following
                                      ? Colors.white.withValues(alpha: 0.22)
                                      : Colors.white,
                                  foregroundColor: following
                                      ? Colors.white
                                      : const Color(0xFF4A3BCF),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(99),
                                    side: following
                                        ? BorderSide(
                                            color: Colors.white.withValues(
                                              alpha: 0.55,
                                            ),
                                          )
                                        : BorderSide.none,
                                  ),
                                ),
                                icon: Icon(
                                  following
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  following ? '단골 팬 · 팔로잉' : '단골 팬 등록 / 팔로우',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (_needsReviewCta && myCare != null) ...[
              const SizedBox(height: 16),
              _AiReviewCtaCard(
                careName: myCare.careName.trim().isEmpty
                    ? '최근 케어'
                    : myCare.careName.trim(),
                onTap: () => widget.onSelectTab?.call(2),
              ),
            ],

            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '원장님의 리얼 B/A 관리 케이스',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onSelectTab?.call(3),
                  child: const Text(
                    '전체 보기',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: SoriTokens.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '공유된 Before/After와 소통 피드',
              style: TextStyle(
                fontSize: 12.5,
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            if (cases.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '아직 공유된 관리 케이스가 없어요.\n곧 다양한 Before/After가 올라올 예정이에요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: SoriTokens.textSecondary,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              SizedBox(
                height: 360,
                child: PageView.builder(
                  controller: PageController(viewportFraction: 0.9),
                  itemCount: cases.length.clamp(0, 12),
                  itemBuilder: (context, index) {
                    final chart = cases[index];
                    final id = chart.id;
                    final likes =
                        _likeCounts[id] ?? (3 + id.hashCode.abs() % 40);
                    final liked = _liked.contains(id);
                    final comments = _comments[id] ?? const <_HomeComment>[];
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _BaCaseSlideCard(
                        chart: chart,
                        liked: liked,
                        likeCount: likes,
                        commentCount: comments.length,
                        onLike: () => _toggleLike(id),
                        onComment: () => _openComments(chart),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AiReviewCtaCard extends StatelessWidget {
  const _AiReviewCtaCard({required this.careName, required this.onTap});

  final String careName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF7ED), Color(0xFFEEECFB)],
            ),
            border: Border.all(color: const Color(0xFFE9D5FF)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: SoriTokens.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: SoriTokens.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '최근 케어 · $careName',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: SoriTokens.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '최근 받으신 케어는 어떠셨나요?\n1초 AI 후기 작성하기',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: SoriTokens.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BaCaseSlideCard extends StatelessWidget {
  const _BaCaseSlideCard({
    required this.chart,
    required this.liked,
    required this.likeCount,
    required this.commentCount,
    required this.onLike,
    required this.onComment,
  });

  final CustomerChart chart;
  final bool liked;
  final int likeCount;
  final int commentCount;
  final VoidCallback onLike;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    final care = chart.careName.trim().isEmpty ? '관리 케어' : chart.careName.trim();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: BeforeAfterSlider(
              height: 220,
              before: ChartImagePane(
                url: chart.beforeImageUrl,
                fallbackLabel: 'Before',
                tone: SoriTokens.primary,
              ),
              after: ChartImagePane(
                url: chart.afterImageUrl,
                fallbackLabel: 'After',
                tone: const Color(0xFF03C75A),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  care,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onLike,
                      icon: Icon(
                        liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                        color: liked ? const Color(0xFFE11D48) : null,
                      ),
                      label: Text(
                        '좋아요 $likeCount',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: liked
                              ? const Color(0xFFE11D48)
                              : SoriTokens.textSecondary,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: onComment,
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                      label: Text(
                        '소통 댓글 $commentCount',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: SoriTokens.textSecondary,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeComment {
  const _HomeComment({
    required this.author,
    required this.body,
    required this.isDirector,
    required this.at,
  });

  final String author;
  final String body;
  final bool isDirector;
  final DateTime at;
}

class _HomeCommentSheet extends StatefulWidget {
  const _HomeCommentSheet({
    required this.comments,
    required this.onSubmit,
  });

  final List<_HomeComment> comments;
  final ValueChanged<String> onSubmit;

  @override
  State<_HomeCommentSheet> createState() => _HomeCommentSheetState();
}

class _HomeCommentSheetState extends State<_HomeCommentSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '소통 댓글',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.35,
            ),
            child: widget.comments.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      '첫 댓글로 응원을 남겨 보세요',
                      style: TextStyle(color: SoriTokens.textSecondary),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.comments.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final c = widget.comments[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          c.isDirector ? '${c.author} · 원장' : c.author,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(c.body),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: '댓글을 입력하세요',
                    filled: true,
                    fillColor: SoriTokens.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  final t = _controller.text.trim();
                  if (t.isEmpty) return;
                  widget.onSubmit(t);
                  _controller.clear();
                  setState(() {});
                },
                style: FilledButton.styleFrom(
                  backgroundColor: SoriTokens.primary,
                ),
                child: const Text('등록'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
