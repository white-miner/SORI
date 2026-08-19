import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/community_case_item.dart';
import '../models/customer_chart.dart';
import '../models/customer_review.dart';
import '../models/session_user.dart';
import '../models/shop.dart';
import '../routing/sori_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/before_after_slider.dart';
import '../widgets/case_feed_viewport.dart';
import '../widgets/case_review_inline.dart';
import '../widgets/sori_logo.dart';

enum _CaseCategory {
  all,
  poreAcne,
  contourLift,
  bodyShape,
  flushMoisture,
}

extension on _CaseCategory {
  String get label => switch (this) {
        _CaseCategory.all => '전체',
        _CaseCategory.poreAcne => '#모공·여드름',
        _CaseCategory.contourLift => '#윤곽·리프팅',
        _CaseCategory.bodyShape => '#복부·체형',
        _CaseCategory.flushMoisture => '#홍조·수분',
      };

  List<String> get keywords => switch (this) {
        _CaseCategory.all => const [],
        _CaseCategory.poreAcne => const [
            '모공',
            '피지',
            '여드름',
            '트러블',
          ],
        _CaseCategory.contourLift => const [
            '윤곽',
            '리프팅',
            '탄력',
            '리프트',
          ],
        _CaseCategory.bodyShape => const [
            '복부',
            '체형',
            '바디',
            '셀룰라이트',
            '부종',
          ],
        _CaseCategory.flushMoisture => const [
            '홍조',
            '수분',
            '민감',
            '건조',
            '장벽',
            '재생',
          ],
      };
}

/// 고객 모드 전용 — 공유된 관리 케이스 소셜 피드.
class CustomerManagementCasesPage extends StatefulWidget {
  const CustomerManagementCasesPage({super.key, required this.store});

  final SoriStore store;

  @override
  State<CustomerManagementCasesPage> createState() =>
      _CustomerManagementCasesPageState();
}

class _CustomerManagementCasesPageState
    extends State<CustomerManagementCasesPage> {
  final _searchController = TextEditingController();
  final _liked = <String>{};
  final _likeCounts = <String, int>{};
  final _comments = <String, List<_CaseComment>>{};
  int _visibleCount = 8;
  _CaseCategory _category = _CaseCategory.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.store.refreshCommunityHotCases();
    });
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    _searchController.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  List<String> _searchTokens(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .split(RegExp(r'[\s,]+'))
        .map((t) => t.replaceFirst(RegExp(r'^#+'), '').trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  String _haystack(CommunityCaseItem item) {
    final chart = item.chart;
    final customer = widget.store.findCustomer(chart.customerId);
    final review = item.review ?? widget.store.reviewForChart(chart.id);
    return [
      chart.careName,
      chart.treatmentSummary,
      chart.directorInsight,
      ...chart.concernChips,
      item.shop.name,
      if (customer != null) customer.name,
      if (customer != null) customer.treatmentType,
      if (review != null) review.displayText,
    ].join(' ').toLowerCase();
  }

  bool _matchesCategory(CommunityCaseItem item) {
    final keys = _category.keywords;
    if (keys.isEmpty) return true;
    final hay = _haystack(item);
    return keys.any((k) => hay.contains(k.toLowerCase()));
  }

  List<CommunityCaseItem> get _feed {
    final base = widget.store.favoriteShopCaseItems();

    final tokens = _searchTokens(_query);
    return base.where((item) {
      if (!_matchesCategory(item)) return false;
      if (tokens.isEmpty) return true;
      final hay = _haystack(item);
      return tokens.every((t) => hay.contains(t));
    }).toList();
  }

  String _anonymize(String? name) {
    final n = (name ?? '').trim();
    if (n.isEmpty) return '익명 고객님';
    final first = n.characters.first;
    return '$first** 고객님';
  }

  Future<void> _openNaver(Shop shop) async {
    final url = shop.naverPlaceUrl.trim();
    if (url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('네이버 예약 링크가 준비 중입니다.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('네이버 예약 링크가 준비 중입니다.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('네이버 예약 링크가 준비 중입니다.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    }
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
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200) {
      if (widget.store.activeCommentPostId == chart.id) {
        widget.store.closeCommentPanel();
      } else {
        widget.store.openCommentPanel(chart.id);
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
        return _CommentSheet(
          comments: list,
          onSubmit: (text) {
            final session = widget.store.session;
            final author = session?.name.trim().isNotEmpty == true
                ? session!.name.trim()
                : '고객';
            final isDirector = session?.activeMode == UserRole.director;
            setState(() {
              list.add(
                _CaseComment(
                  author: author,
                  body: text,
                  isDirector: isDirector,
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
    final feed = _feed;
    final shown = feed.take(_visibleCount).toList();
    final loading = widget.store.communityHotCasesLoading && shown.isEmpty;

    return ColoredBox(
      color: const Color(0xFFF5F6F8),
      child: SafeArea(
        child: CaseFeedViewport(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Text(
                '단골 샵의 공유 B/A 케이스 · 전국 탐색은 홈 탭에서',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() {
                  _query = v;
                  _visibleCount = 8;
                }),
                decoration: InputDecoration(
                  hintText: '#홍조 #테라노바 증상·시술명 검색',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                children: _CaseCategory.values.map((cat) {
                  final selected = _category == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        cat.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: selected
                              ? SoriTokens.primary
                              : Colors.grey.shade700,
                        ),
                      ),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _category = cat;
                        _visibleCount = 8;
                      }),
                      selectedColor: SoriTokens.primarySoft,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: selected
                            ? SoriTokens.primary.withValues(alpha: 0.35)
                            : const Color(0xFFE5E7EB),
                      ),
                      showCheckmark: false,
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? _CasesEmptyState(
                      loading: loading,
                      onGoHome: () => context.go(AppPaths.appHome),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.metrics.pixels >=
                            n.metrics.maxScrollExtent - 120) {
                          if (_visibleCount < feed.length) {
                            setState(() {
                              _visibleCount =
                                  (_visibleCount + 6).clamp(0, feed.length);
                            });
                          }
                        }
                        return false;
                      },
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        itemCount: shown.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final item = shown[index];
                          final id = item.chart.id;
                          final likes = _likeCounts[id] ??
                              (3 + id.hashCode.abs() % 40);
                          final liked = _liked.contains(id);
                          final comments =
                              _comments[id] ?? const <_CaseComment>[];
                          final customer =
                              widget.store.findCustomer(item.chart.customerId);
                          return _CustomerCaseCard(
                            shop: item.shop,
                            chart: item.chart,
                            anonymousCustomer: _anonymize(customer?.name),
                            review: item.review ??
                                widget.store.reviewForChart(item.chart.id),
                            liked: liked,
                            likeCount: likes,
                            commentCount: comments.length,
                            onLike: () => _toggleLike(id),
                            onComment: () => _openComments(item.chart),
                            onBook: () => _openNaver(item.shop),
                          );
                        },
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

class _CasesEmptyState extends StatelessWidget {
  const _CasesEmptyState({
    required this.loading,
    required this.onGoHome,
  });

  final bool loading;
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: SoriTokens.primary),
            SizedBox(height: 14),
            Text(
              '핫 케이스를 불러오는 중…',
              style: TextStyle(
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: SoriTokens.primarySoft.withValues(alpha: 0.65),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_outlined,
                size: 40,
                color: SoriTokens.primary.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '등록된 B/A 케이스를 준비 중입니다 ✨',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: SoriTokens.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '곧 다양한 Before/After와 리얼 후기가 올라올 예정이에요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onGoHome,
              style: FilledButton.styleFrom(
                backgroundColor: SoriTokens.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.home_rounded, size: 18),
              label: const Text(
                '홈으로 가기',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerCaseCard extends StatelessWidget {
  const _CustomerCaseCard({
    required this.shop,
    required this.chart,
    required this.anonymousCustomer,
    required this.liked,
    required this.likeCount,
    required this.commentCount,
    required this.onLike,
    required this.onComment,
    required this.onBook,
    this.review,
  });

  final Shop shop;
  final CustomerChart chart;
  final String anonymousCustomer;
  final bool liked;
  final int likeCount;
  final int commentCount;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onBook;
  final CustomerReview? review;

  @override
  Widget build(BuildContext context) {
    final care = chart.careName.isNotEmpty
        ? chart.careName
        : (chart.treatmentSummary.isNotEmpty
            ? chart.treatmentSummary
            : '관리 케어');
    final insight = chart.directorInsight.trim().isNotEmpty
        ? chart.directorInsight.trim()
        : (chart.treatmentSummary.trim().isNotEmpty
            ? chart.treatmentSummary.trim()
            : '시술 후 피부 컨디션이 안정적으로 개선되었어요.');
    final owner = (shop.ownerName ?? '').trim().isEmpty
        ? '원장'
        : shop.ownerName!.trim();
    final hasReview = review != null && review!.displayText.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: SoriTokens.primarySoft,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: SoriLogo(width: 28, height: 28),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '원장 $owner',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
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
          BeforeAfterSlider(
            aspectRatio: 4 / 3,
            maxHeight: 520,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  care,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  anonymousCustomer,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  insight,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (hasReview) CaseReviewInlineBlock(review: review!),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: onLike,
                  icon: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? const Color(0xFFE53935) : Colors.grey[700],
                  ),
                ),
                Text(
                  '$likeCount',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onComment,
                  icon: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  '$commentCount',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: onBook,
                style: FilledButton.styleFrom(
                  backgroundColor: SoriTokens.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '샵 정보 더보기 / 예약하기',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseComment {
  const _CaseComment({
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

class _CommentSheet extends StatefulWidget {
  const _CommentSheet({
    required this.comments,
    required this.onSubmit,
  });

  final List<_CaseComment> comments;
  final ValueChanged<String> onSubmit;

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
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
        height: MediaQuery.sizeOf(context).height * 0.55,
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
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
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
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: c.isDirector
                                    ? SoriTokens.primarySoft
                                    : const Color(0xFFEEF2F7),
                                child: Icon(
                                  c.isDirector
                                      ? Icons.storefront_outlined
                                      : Icons.person_outline,
                                  size: 16,
                                  color: c.isDirector
                                      ? SoriTokens.primary
                                      : Colors.grey[700],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.isDirector
                                          ? '${c.author} · 원장'
                                          : c.author,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      c.body,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                        hintText: '댓글을 입력하세요',
                        filled: true,
                        fillColor: const Color(0xFFF5F6F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
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
                      foregroundColor: Colors.white,
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
