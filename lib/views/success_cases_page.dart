import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/community_case_item.dart';
import '../models/customer.dart';
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
import '../widgets/sori_card.dart';
import '../widgets/sori_logo.dart';
import 'customer_management_cases_page.dart';

enum _CaseScope { nationwide, myShop }

enum _NationwideFilter {
  all,
  terranova,
  bodyShape,
  contourLift,
  acneFlush,
  popular,
}

enum _MyShopShareFilter { all, shared, private }

extension on _NationwideFilter {
  String get label => switch (this) {
        _NationwideFilter.all => '전체',
        _NationwideFilter.terranova => '#테라노바',
        _NationwideFilter.bodyShape => '#복부·체형',
        _NationwideFilter.contourLift => '#윤곽·리프팅',
        _NationwideFilter.acneFlush => '#여드름·홍조',
        _NationwideFilter.popular => '#인기순',
      };

  List<String> get keywords => switch (this) {
        _NationwideFilter.all || _NationwideFilter.popular => const [],
        _NationwideFilter.terranova => const ['테라노바'],
        _NationwideFilter.bodyShape => const [
            '복부',
            '체형',
            '바디',
            '셀룰라이트',
            '부종',
          ],
        _NationwideFilter.contourLift => const [
            '윤곽',
            '리프팅',
            '탄력',
            '리프트',
          ],
        _NationwideFilter.acneFlush => const [
            '여드름',
            '홍조',
            '모공',
            '피지',
            '트러블',
            '민감',
          ],
      };
}

/// 관리 케이스 — 전국 원장님 탐색 / 내 샵 큐레이션.
class SuccessCasesPage extends StatefulWidget {
  const SuccessCasesPage({super.key, required this.store});

  final SoriStore store;

  @override
  State<SuccessCasesPage> createState() => _SuccessCasesPageState();
}

class _SuccessCasesPageState extends State<SuccessCasesPage> {
  final _searchController = TextEditingController();
  final _liked = <String>{};
  final _likeCounts = <String, int>{};
  final _comments = <String, List<_DirectorCaseComment>>{};
  String _query = '';
  _CaseScope _scope = _CaseScope.nationwide;
  _NationwideFilter _nationwideFilter = _NationwideFilter.all;
  _MyShopShareFilter _myShopFilter = _MyShopShareFilter.all;

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

  bool _hasComparableImages(CustomerChart chart) {
    final b = chart.beforeImageUrl?.trim() ?? '';
    final a = chart.afterImageUrl?.trim() ?? '';
    return b.isNotEmpty || a.isNotEmpty;
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

  String _haystackForChart(CustomerChart chart, Customer? customer) {
    return [
      chart.careName,
      chart.treatmentSummary,
      chart.directorInsight,
      ...chart.concernChips,
      ...chart.firstVisitFearChips,
      ...chart.revisitFeedbackChips,
      if (customer != null) customer.name,
      if (customer != null) customer.treatmentType,
    ].join(' ').toLowerCase();
  }

  String _haystackForCommunity(CommunityCaseItem item) {
    final review = item.review;
    return [
      _haystackForChart(item.chart, null),
      item.shop.name,
      item.shop.ownerName ?? '',
      if (review != null) review.displayText,
    ].join(' ').toLowerCase();
  }

  int _popularityScore(String chartId) {
    final likes = _likeCounts[chartId] ?? (8 + chartId.hashCode.abs() % 55);
    final comments = (_comments[chartId]?.length ?? 0) +
        (chartId.hashCode.abs() % 9);
    return likes * 3 + comments * 2 + (chartId.hashCode.abs() % 20);
  }

  List<CommunityCaseItem> get _nationwideCases {
    var items = List<CommunityCaseItem>.from(widget.store.communityHotCases);
    if (items.isEmpty) {
      // 로딩 전/실패 시 내 샵 공유 케이스로 폴백
      items = widget.store.favoriteShopCaseItems();
    }

    final keys = _nationwideFilter.keywords;
    final tokens = _searchTokens(_query);
    items = items.where((item) {
      if (!_hasComparableImages(item.chart)) return false;
      if (!item.chart.caseShared) return false;
      final hay = _haystackForCommunity(item);
      if (keys.isNotEmpty && !keys.any((k) => hay.contains(k.toLowerCase()))) {
        return false;
      }
      if (tokens.isNotEmpty && !tokens.every((t) => hay.contains(t))) {
        return false;
      }
      return true;
    }).toList();

    if (_nationwideFilter == _NationwideFilter.popular) {
      items.sort(
        (a, b) =>
            _popularityScore(b.chart.id).compareTo(_popularityScore(a.chart.id)),
      );
    } else {
      items.sort((a, b) {
        final ad = a.chart.visitCheckedAt ??
            a.chart.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.chart.visitCheckedAt ??
            b.chart.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
    }
    return items;
  }

  List<({CustomerChart chart, Customer? customer})> get _myShopCases {
    final tokens = _searchTokens(_query);
    final myShopId = widget.store.shop.id;
    final out = <({CustomerChart chart, Customer? customer})>[];
    for (final chart in widget.store.charts) {
      if (!_hasComparableImages(chart)) continue;
      if (chart.shopId.isNotEmpty &&
          myShopId.isNotEmpty &&
          chart.shopId != myShopId) {
        continue;
      }

      final shared = chart.isConsentSigned && chart.caseShared;
      switch (_myShopFilter) {
        case _MyShopShareFilter.shared:
          if (!shared) continue;
        case _MyShopShareFilter.private:
          if (shared) continue;
        case _MyShopShareFilter.all:
          break;
      }

      final customer = widget.store.findCustomer(chart.customerId);
      if (tokens.isNotEmpty) {
        final hay = _haystackForChart(chart, customer);
        if (!tokens.every((t) => hay.contains(t))) continue;
      }
      out.add((chart: chart, customer: customer));
    }
    out.sort((a, b) {
      final ad = a.chart.visitCheckedAt ??
          a.chart.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.chart.visitCheckedAt ??
          b.chart.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return out;
  }

  void _onShareToggle(CustomerChart chart, bool value) {
    final ok = widget.store.setManagementCaseShared(chart.id, value);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('고객의 정보 활용 동의서 서명이 완료된 차트만 공유할 수 있습니다.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFE53935),
        ),
      );
    }
  }

  void _onDisabledToggleTap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('고객의 정보 활용 동의서 서명이 완료된 차트만 공유할 수 있습니다.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFFE53935),
      ),
    );
  }

  void _toggleLike(String chartId) {
    setState(() {
      final base = _likeCounts[chartId] ?? (8 + chartId.hashCode.abs() % 55);
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
        return _DirectorCommentSheet(
          comments: list,
          onSubmit: (text) {
            final session = widget.store.session;
            final author = session?.name.trim().isNotEmpty == true
                ? session!.name.trim()
                : '원장';
            setState(() {
              list.add(
                _DirectorCaseComment(
                  author: author,
                  body: text,
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
    final isCustomer =
        widget.store.session?.activeMode == UserRole.customer;
    if (isCustomer) {
      return CustomerManagementCasesPage(store: widget.store);
    }

    final nationwide = _nationwideCases;
    final myShop = _myShopCases;
    final loading = widget.store.communityHotCasesLoading &&
        _scope == _CaseScope.nationwide;

    return SafeArea(
      child: CaseFeedViewport(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<_CaseScope>(
                groupValue: _scope,
                backgroundColor: const Color(0xFFF0F1F3),
                thumbColor: Colors.white,
                padding: const EdgeInsets.all(3),
                children: {
                  _CaseScope.nationwide: _seg('🌟 전국 원장님 케이스'),
                  _CaseScope.myShop: _seg('🌿 내 샵 관리 케이스'),
                },
                onValueChanged: (v) {
                  if (v == null) return;
                  setState(() => _scope = v);
                  if (v == _CaseScope.nationwide) {
                    widget.store.refreshCommunityHotCases();
                  }
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              _scope == _CaseScope.nationwide
                  ? '전국 샵에서 공유된 B/A 케이스를 탐색·연구하고 원장님끼리 소통하세요'
                  : '내 샵 고객 B/A만 모아 큐레이션하고, 피드 공유를 즉시 전환합니다',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: _scope == _CaseScope.nationwide
                    ? '#테라노바 #윤곽 프로토콜·샵명 검색'
                    : '#홍조 #테라노바 증상·시술명 검색',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_scope == _CaseScope.nationwide)
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                children: _NationwideFilter.values.map((f) {
                  final selected = _nationwideFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        f.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: selected
                              ? SoriTokens.primary
                              : Colors.grey.shade700,
                        ),
                      ),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _nationwideFilter = f),
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
            )
          else
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                children: [
                  _myShopChip(
                    label: '전체',
                    selected: _myShopFilter == _MyShopShareFilter.all,
                    onTap: () => setState(
                      () => _myShopFilter = _MyShopShareFilter.all,
                    ),
                  ),
                  _myShopChip(
                    label: '피드 공유 중',
                    selected: _myShopFilter == _MyShopShareFilter.shared,
                    onTap: () => setState(
                      () => _myShopFilter = _MyShopShareFilter.shared,
                    ),
                  ),
                  _myShopChip(
                    label: '비공개',
                    selected: _myShopFilter == _MyShopShareFilter.private,
                    onTap: () => setState(
                      () => _myShopFilter = _MyShopShareFilter.private,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _scope == _CaseScope.nationwide
                ? _buildNationwideList(nationwide, loading)
                : _buildMyShopList(myShop),
          ),
        ],
        ),
      ),
    );
  }

  Widget _myShopChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: selected ? SoriTokens.primary : Colors.grey.shade700,
          ),
        ),
        selected: selected,
        onSelected: (_) => onTap(),
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
  }

  Widget _buildNationwideList(List<CommunityCaseItem> items, bool loading) {
    if (items.isEmpty) {
      return _DirectorCasesEmptyState(
        queryEmpty: _query.trim().isEmpty &&
            _nationwideFilter == _NationwideFilter.all,
        nationwide: true,
        loading: loading,
        onGoHome: () => context.go(AppPaths.appHome),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        final id = item.chart.id;
        final likes = _likeCounts[id] ?? (8 + id.hashCode.abs() % 55);
        final comments = _comments[id] ?? const <_DirectorCaseComment>[];
        return _NationwideCaseCard(
          shop: item.shop,
          chart: item.chart,
          review: item.review ?? widget.store.reviewForChart(id),
          liked: _liked.contains(id),
          likeCount: likes,
          commentCount: comments.length,
          onLike: () => _toggleLike(id),
          onComment: () => _openComments(item.chart),
        );
      },
    );
  }

  Widget _buildMyShopList(
    List<({CustomerChart chart, Customer? customer})> cases,
  ) {
    if (cases.isEmpty) {
      return _DirectorCasesEmptyState(
        queryEmpty: _query.trim().isEmpty,
        nationwide: false,
        loading: false,
        onGoHome: () => context.go(AppPaths.appHome),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      itemCount: cases.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = cases[index];
        return _MyShopCaseCard(
          chart: item.chart,
          customer: item.customer,
          review: widget.store.reviewForChart(item.chart.id),
          onShareChanged: (v) => _onShareToggle(item.chart, v),
          onDisabledTap: _onDisabledToggleTap,
        );
      },
    );
  }

  Widget _seg(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DirectorCasesEmptyState extends StatelessWidget {
  const _DirectorCasesEmptyState({
    required this.queryEmpty,
    required this.nationwide,
    required this.loading,
    required this.onGoHome,
  });

  final bool queryEmpty;
  final bool nationwide;
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
              '전국 원장님 케이스를 불러오는 중…',
              style: TextStyle(
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final title = !queryEmpty
        ? '검색 조건에 맞는 관리 케이스가 없습니다'
        : '등록된 B/A 케이스를 준비 중입니다 ✨';
    final subtitle = !queryEmpty
        ? '다른 키워드·필터로 다시 탐색해 보세요.'
        : (nationwide
            ? '다른 샵에서 공유를 켜면 여기에 최신·인기 케이스가 모입니다.'
            : '차트에 Before/After를 남기면 내 샵 큐레이션에 표시됩니다.');

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
                nationwide
                    ? Icons.travel_explore_rounded
                    : Icons.photo_library_outlined,
                size: 40,
                color: SoriTokens.primary.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: SoriTokens.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
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

class _NationwideCaseCard extends StatelessWidget {
  const _NationwideCaseCard({
    required this.shop,
    required this.chart,
    required this.liked,
    required this.likeCount,
    required this.commentCount,
    required this.onLike,
    required this.onComment,
    this.review,
  });

  final Shop shop;
  final CustomerChart chart;
  final bool liked;
  final int likeCount;
  final int commentCount;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final CustomerReview? review;

  @override
  Widget build(BuildContext context) {
    final care = chart.careName.isNotEmpty
        ? chart.careName
        : (chart.treatmentSummary.isNotEmpty
            ? chart.treatmentSummary
            : '관리 케이스');
    final tip = chart.directorInsight.trim().isNotEmpty
        ? chart.directorInsight.trim()
        : (chart.treatmentSummary.trim().isNotEmpty
            ? chart.treatmentSummary.trim()
            : '관리 프로토콜 팁이 곧 업데이트됩니다.');
    final owner = (shop.ownerName ?? '').trim().isEmpty
        ? '원장'
        : shop.ownerName!.trim();
    final hasReview = review != null && review!.displayText.trim().isNotEmpty;

    return SoriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: SoriTokens.primarySoft,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: SoriLogo(width: 24, height: 24),
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
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          Text(
            care,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F7FC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SoriTokens.primarySoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '관리 프로토콜 팁',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: SoriTokens.primary.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (hasReview) CaseReviewInlineBlock(review: review!),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                onPressed: onLike,
                tooltip: '원장님 좋아요',
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
                tooltip: '원장님 댓글',
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
              const Spacer(),
              Text(
                '원장 간 소통',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MyShopCaseCard extends StatelessWidget {
  const _MyShopCaseCard({
    required this.chart,
    required this.customer,
    required this.onShareChanged,
    required this.onDisabledTap,
    this.review,
  });

  final CustomerChart chart;
  final Customer? customer;
  final ValueChanged<bool> onShareChanged;
  final VoidCallback onDisabledTap;
  final CustomerReview? review;

  int get _viewCount => 48 + chart.id.hashCode.abs() % 420;
  int get _likeCount => 3 + chart.id.hashCode.abs() % 40;
  int get _commentCount => chart.id.hashCode.abs() % 14;

  @override
  Widget build(BuildContext context) {
    final title = chart.careName.isNotEmpty
        ? chart.careName
        : (chart.treatmentSummary.isNotEmpty
            ? chart.treatmentSummary
            : '관리 케이스');
    final tags = <String>[
      ...chart.concernChips.take(3),
      if (chart.careName.isNotEmpty) chart.careName,
    ];
    final canShare = chart.isConsentSigned;
    final shareOn = canShare && chart.caseShared;
    final hasReview = review != null && review!.displayText.trim().isNotEmpty;

    return SoriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (hasReview) const VerifiedReviewBadge(small: true),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (customer != null) customer!.name,
                        '${chart.visitNumber}회차',
                        if (chart.isConsentSigned) '동의 서명 완료',
                        if (!chart.isConsentSigned) '동의 미서명',
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Material(
            color: canShare
                ? SoriTokens.primarySoft.withValues(alpha: 0.55)
                : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: canShare ? null : onDisabledTap,
              child: IgnorePointer(
                ignoring: !canShare,
                child: Opacity(
                  opacity: canShare ? 1 : 0.55,
                  child: SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
                    dense: true,
                    title: const Text(
                      '피드 공유',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      canShare
                          ? (shareOn
                              ? '전국 피드에 공개 중'
                              : '비공개 · 켜면 즉시 공개')
                          : '동의 서명 후 공유 가능',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    value: shareOn,
                    activeThumbColor: SoriTokens.primary,
                    onChanged: canShare ? onShareChanged : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
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
          if (shareOn) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _EngagementBadge(
                  icon: Icons.visibility_outlined,
                  label: '조회수 $_viewCount',
                ),
                _EngagementBadge(
                  icon: Icons.favorite_border_rounded,
                  label: '좋아요 $_likeCount',
                ),
                _EngagementBadge(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '댓글 $_commentCount',
                ),
              ],
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: SoriTokens.primarySoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '#$t',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: SoriTokens.primary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (hasReview) CaseReviewInlineBlock(review: review!),
        ],
      ),
    );
  }
}

class _EngagementBadge extends StatelessWidget {
  const _EngagementBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectorCaseComment {
  const _DirectorCaseComment({
    required this.author,
    required this.body,
    required this.at,
  });

  final String author;
  final String body;
  final DateTime at;
}

class _DirectorCommentSheet extends StatefulWidget {
  const _DirectorCommentSheet({
    required this.comments,
    required this.onSubmit,
  });

  final List<_DirectorCaseComment> comments;
  final ValueChanged<String> onSubmit;

  @override
  State<_DirectorCommentSheet> createState() => _DirectorCommentSheetState();
}

class _DirectorCommentSheetState extends State<_DirectorCommentSheet> {
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
                  '원장님 댓글',
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
                        '첫 프로토콜 코멘트를 남겨 보세요',
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
                                backgroundColor: SoriTokens.primarySoft,
                                child: Icon(
                                  Icons.storefront_outlined,
                                  size: 16,
                                  color: SoriTokens.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${c.author} · 원장',
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
                        hintText: '프로토콜·노하우 댓글 입력',
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
