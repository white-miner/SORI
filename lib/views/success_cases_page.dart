import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../models/customer_review.dart';
import '../models/session_user.dart';
import '../routing/sori_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/before_after_slider.dart';
import '../widgets/case_review_inline.dart';
import '../widgets/sori_card.dart';
import 'customer_management_cases_page.dart';

enum _CaseScope { shared, myShop }

/// 관리 케이스 — 공유 피드 / 내 샵 관리 + 동의서 기반 공유 토글.
class SuccessCasesPage extends StatefulWidget {
  const SuccessCasesPage({super.key, required this.store});

  final SoriStore store;

  @override
  State<SuccessCasesPage> createState() => _SuccessCasesPageState();
}

class _SuccessCasesPageState extends State<SuccessCasesPage> {
  final _searchController = TextEditingController();
  String _query = '';
  _CaseScope _scope = _CaseScope.myShop;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
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

  String _haystack(CustomerChart chart, Customer? customer) {
    final parts = <String>[
      chart.careName,
      chart.treatmentSummary,
      chart.directorInsight,
      ...chart.concernChips,
      ...chart.firstVisitFearChips,
      ...chart.revisitFeedbackChips,
      if (customer != null) customer.name,
      if (customer != null) customer.treatmentType,
    ];
    return parts.join(' ').toLowerCase();
  }

  List<({CustomerChart chart, Customer? customer})> get _cases {
    final tokens = _searchTokens(_query);
    final out = <({CustomerChart chart, Customer? customer})>[];
    for (final chart in widget.store.charts) {
      if (!_hasComparableImages(chart)) continue;

      if (_scope == _CaseScope.shared) {
        // 공유 피드: 동의 서명 + 공유 ON 만
        if (!chart.isConsentSigned || !chart.caseShared) continue;
      }
      // 내 샵: 동의 여부와 무관하게 B/A 있는 모든 차트 열람

      final customer = widget.store.findCustomer(chart.customerId);
      if (tokens.isNotEmpty) {
        final hay = _haystack(chart, customer);
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

  @override
  Widget build(BuildContext context) {
    final isCustomer =
        widget.store.session?.activeMode == UserRole.customer;
    if (isCustomer) {
      // 고객 모드는 공유 피드만 (스위치 숨김)
      return CustomerManagementCasesPage(store: widget.store);
    }

    final cases = _cases;

    return SafeArea(
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
                  _CaseScope.shared: _seg('공유된 관리 케이스'),
                  _CaseScope.myShop: _seg('내 샵 관리 케이스'),
                },
                onValueChanged: (v) {
                  if (v == null) return;
                  setState(() => _scope = v);
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              _scope == _CaseScope.shared
                  ? '동의 서명이 완료되고 공유가 켜진 케이스만 표시됩니다'
                  : '내 샵 차트는 동의 여부와 관계없이 열람할 수 있습니다. 공유는 서명 완료 차트만 가능합니다.',
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
                hintText: '#홍조 #테라노바 증상·시술명 검색',
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
          Expanded(
            child: cases.isEmpty
                ? _DirectorCasesEmptyState(
                    queryEmpty: _query.trim().isEmpty,
                    sharedScope: _scope == _CaseScope.shared,
                    onGoHome: () => context.go(AppPaths.appHome),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                    itemCount: cases.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = cases[index];
                      return _CaseCard(
                        chart: item.chart,
                        customer: item.customer,
                        review: widget.store.reviewForChart(item.chart.id),
                        showShareToggle: _scope == _CaseScope.myShop,
                        onShareChanged: (v) => _onShareToggle(item.chart, v),
                        onDisabledTap: _onDisabledToggleTap,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _seg(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DirectorCasesEmptyState extends StatelessWidget {
  const _DirectorCasesEmptyState({
    required this.queryEmpty,
    required this.sharedScope,
    required this.onGoHome,
  });

  final bool queryEmpty;
  final bool sharedScope;
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    final title = !queryEmpty
        ? '검색 조건에 맞는 관리 케이스가 없습니다'
        : (sharedScope
            ? '등록된 B/A 케이스를 준비 중입니다 ✨'
            : '등록된 B/A 케이스를 준비 중입니다 ✨');
    final subtitle = !queryEmpty
        ? '다른 키워드로 다시 검색해 보세요.'
        : (sharedScope
            ? '동의 서명 후 케이스 공유 스위치를 켜면 피드에 노출됩니다.'
            : '차트에 Before/After 사진을 남기면 여기에 모입니다.');

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
                Icons.photo_library_outlined,
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

class _CaseCard extends StatelessWidget {
  const _CaseCard({
    required this.chart,
    required this.customer,
    required this.showShareToggle,
    required this.onShareChanged,
    required this.onDisabledTap,
    this.review,
  });

  final CustomerChart chart;
  final Customer? customer;
  final bool showShareToggle;
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
    final showEngagement = chart.caseShared && chart.isConsentSigned;

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
          if (showShareToggle) ...[
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
                        '케이스 공유',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        canShare
                            ? (shareOn
                                ? '피드에 공개 중 · 1초 토글'
                                : '꺼져 있음 · 켜면 즉시 공개')
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
          ],
          const SizedBox(height: 12),
          BeforeAfterSlider(
            height: 220,
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
          if (showEngagement) ...[
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
