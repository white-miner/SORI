import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../routing/sori_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/care_episode_group.dart';
import '../widgets/case_review_inline.dart';
import 'admin_chart_writer_page.dart';
import 'before_after_compare_sheet.dart';
import 'chart_management_page.dart';
import 'customer_link_popup.dart';
import 'membership_editor_sheet.dart';
import 'my_app.dart';
import 'request_customer_review.dart';

/// 원장용: 회차 다이렉트 리스트 + Before/After 갤러리.
class AdminChartPage extends StatefulWidget {
  const AdminChartPage({
    super.key,
    required this.store,
    required this.customerId,
  });

  final SoriStore store;
  final String customerId;

  @override
  State<AdminChartPage> createState() => _AdminChartPageState();
}

class _AdminChartPageState extends State<AdminChartPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    widget.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Customer? get _customer => widget.store.findCustomer(widget.customerId);

  List<CustomerChart> get _timeline =>
      widget.store.chartsForCustomer(widget.customerId);

  Future<void> _openChartManagement({String? chartId}) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ChartManagementPage(
          store: widget.store,
          customerId: widget.customerId,
          initialChartId: chartId,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openWriter({
    CustomerChart? chart,
    bool forceQuickChart = false,
  }) async {
    final customer = _customer;
    if (customer == null) return;
    await openChartWriterForCustomer(
      context,
      store: widget.store,
      customer: customer,
      existingChart: chart,
      forceQuickChart: forceQuickChart,
    );
    // Store 리스너가 타임라인을 갱신하지만, 복귀 직후 한 번 더 보장.
    if (mounted) setState(() {});
  }

  Future<void> _openMembershipSheet() async {
    final customer = _customer;
    if (customer == null) return;
    final result = await showMembershipEditorSheet(
      context: context,
      store: widget.store,
      customer: customer,
      persistImmediately: true,
    );
    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isEmpty
              ? '회원권을 비웠습니다'
              : '회원권 ${result.length}종이 저장됐어요',
        ),
        backgroundColor: MyApp.soriPurple,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openBeforeAfterCompare() async {
    await showBeforeAfterCompareSheet(
      context: context,
      charts: _timeline,
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;
    if (customer == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('차트 관리'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppPaths.appCustomers);
              }
            },
          ),
        ),
        body: const Center(child: Text('고객 정보를 찾을 수 없습니다.')),
      );
    }

    final timeline = _timeline;

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: Text(customer.name),
        backgroundColor: SoriTokens.surface,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppPaths.appCustomers);
            }
          },
        ),
        actions: [
          TextButton.icon(
            onPressed: () => requestCustomerReviewWithQr(
              context,
              store: widget.store,
              customer: customer,
            ),
            icon: const Icon(Icons.qr_code_2_rounded, size: 18),
            label: const Text(
              '후기 요청',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: SoriTokens.onPrimary,
          unselectedLabelColor: SoriTokens.textCharcoal,
          indicator: const BoxDecoration(
            color: SoriTokens.primary,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: '타임라인'),
            Tab(text: 'Before/After'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _Header(
              customer: customer,
              lastVisitLabel: timeline.isEmpty
                  ? null
                  : _formatChartDate(timeline.first),
              onTap: () => context.push(AppPaths.customerProfile(customer.id)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: _QuickActionDashboard(
              onMembership: _openMembershipSheet,
              onQuickChart: () => _openWriter(forceQuickChart: true),
              onChartManage: _openChartManagement,
              onBeforeAfter: _openBeforeAfterCompare,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _TimelineTab(
                  timeline: timeline,
                  onOpenChart: (chart) =>
                      _openChartManagement(chartId: chart.id),
                ),
                _GalleryTab(
                  timeline: timeline,
                  onOpenChart: (chart) =>
                      _openChartManagement(chartId: chart.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatChartDate(CustomerChart chart) {
  final dt = chart.visitCheckedAt ?? chart.feedbackLineOpenedAt ?? chart.createdAt;
  if (dt == null) return '날짜 미정';
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y.$m.$d';
}

class _Header extends StatelessWidget {
  const _Header({
    required this.customer,
    required this.onTap,
    this.lastVisitLabel,
  });

  final Customer customer;
  final VoidCallback onTap;
  final String? lastVisitLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: SoriTokens.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFFE5E5EA),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    customer.name.characters.first,
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.nameWithAge,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customer.phone,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (customer.isMembershipCustomer) ...[
                        const SizedBox(height: 6),
                        Text(
                          customer.membershipBadgeLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                      if (lastVisitLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '최근 방문: $lastVisitLabel',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionDashboard extends StatelessWidget {
  const _QuickActionDashboard({
    required this.onMembership,
    required this.onQuickChart,
    required this.onChartManage,
    required this.onBeforeAfter,
  });

  final VoidCallback onMembership;
  final VoidCallback onQuickChart;
  final VoidCallback onChartManage;
  final VoidCallback onBeforeAfter;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _BentoCard(
                title: '1초 간편 차트',
                subtitle: '신규 회차 작성',
                icon: Icons.bolt_rounded,
                iconBg: const Color(0xFFF4F4F5),
                iconFg: const Color(0xFF111111),
                onTap: onQuickChart,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BentoCard(
                title: '차트 관리',
                subtitle: '열람 · 수정',
                icon: Icons.folder_open_rounded,
                iconBg: const Color(0xFFF4F4F5),
                iconFg: const Color(0xFF111111),
                onTap: onChartManage,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _BentoCard(
                title: '회원권 관리',
                subtitle: '등록·수정',
                icon: Icons.card_membership_rounded,
                iconBg: const Color(0xFFE5E5EA),
                iconFg: const Color(0xFF111111),
                onTap: onMembership,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BentoCard(
                title: 'B/A 비교',
                subtitle: '경과 보기',
                icon: Icons.compare_rounded,
                iconBg: const Color(0xFFE5E5EA),
                iconFg: const Color(0xFF111111),
                onTap: onBeforeAfter,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BentoCard extends StatelessWidget {
  const _BentoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: SoriTokens.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.045),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _QuickIcon(
                  icon: icon,
                  bg: iconBg,
                  fg: iconFg,
                  size: 42,
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: SoriTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickIcon extends StatelessWidget {
  const _QuickIcon({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.size,
  });

  final IconData icon;
  final Color bg;
  final Color fg;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: fg, size: size * 0.46),
    );
  }
}

class _TimelineTab extends StatelessWidget {
  const _TimelineTab({
    required this.timeline,
    required this.onOpenChart,
  });

  final List<CustomerChart> timeline;
  final ValueChanged<CustomerChart> onOpenChart;

  @override
  Widget build(BuildContext context) {
    if (timeline.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SoriTokens.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SoriTokens.border),
            ),
            child: const Text('아직 작성된 차트가 없습니다. 새 차트를 작성해 주세요.'),
          ),
        ],
      );
    }

    final episodes = groupChartsByCareName(timeline);
    final rows = <Widget>[
      const Padding(
        padding: EdgeInsets.only(bottom: 4),
        child: Text(
          '시술별 회차',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    ];
    for (final episode in episodes) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Text(
            '${episode.careLabel} · ${episode.visits.length}회',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: SoriTokens.textPrimary,
            ),
          ),
        ),
      );
      for (final chart in episode.visits) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _VisitChartCard(
              chart: chart,
              careLabel: episode.careLabel,
              onTap: () => onOpenChart(chart),
            ),
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: rows,
    );
  }
}

class _VisitChartCard extends StatelessWidget {
  const _VisitChartCard({
    required this.chart,
    required this.onTap,
    this.careLabel,
  });

  final CustomerChart chart;
  final VoidCallback onTap;
  final String? careLabel;

  @override
  Widget build(BuildContext context) {
    final care = (careLabel ?? chart.careName).trim().isNotEmpty
        ? (careLabel ?? chart.careName).trim()
        : (chart.treatmentSummary.isNotEmpty
            ? chart.treatmentSummary
            : '시술 기록');

    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SoriTokens.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SoriTokens.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${chart.visitNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: SoriTokens.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${chart.visitNumber}회차',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: SoriTokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatChartDate(chart)} · $care',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (chart.needsAfterPhoto)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: SoriTokens.warningBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'After 대기',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: SoriTokens.warningText,
                      ),
                    ),
                  ),
                ),
              if (chart.visitChecked)
                Icon(
                  Icons.check_circle,
                  size: 18,
                  color: SoriTokens.textSecondary,
                ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: SoriTokens.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartDetailBody extends StatelessWidget {
  const _ChartDetailBody({
    required this.chart,
    required this.store,
    this.scrollController,
    this.compact = false,
    this.onEdit,
    this.onShowLink,
    this.onConfirmOnly,
    this.onOpenFullDetail,
    this.onAddAfterPhoto,
    this.onOpenManage,
  });

  final CustomerChart chart;
  final SoriStore store;
  final ScrollController? scrollController;
  final bool compact;
  final VoidCallback? onEdit;
  final VoidCallback? onShowLink;
  final VoidCallback? onConfirmOnly;
  final VoidCallback? onOpenFullDetail;
  final VoidCallback? onAddAfterPhoto;
  final VoidCallback? onOpenManage;

  @override
  Widget build(BuildContext context) {
    final care = chart.careName.isNotEmpty
        ? chart.careName
        : (chart.treatmentSummary.isNotEmpty
            ? chart.treatmentSummary
            : '시술 기록');
    final review = store.reviewForChart(chart.id);

    final children = <Widget>[
      if (!compact) ...[
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Text(
          '${_formatChartDate(chart)} (${chart.visitNumber}회차)',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          care,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 16),
      ],
      _detailBlock('차트 번호', '차트 ${chart.displayChartNo}'),
      _detailBlock('진행 서비스', care),
      if (chart.customerRequests.trim().isNotEmpty)
        _detailBlock('고객 요청사항', chart.customerRequests),
      if (chart.allergyNotes.trim().isNotEmpty ||
          chart.skinSensitivity.trim().isNotEmpty ||
          chart.sideEffectHistory.trim().isNotEmpty)
        _detailBlock(
          '메디컬 체크',
          [
            if (chart.allergyNotes.trim().isNotEmpty)
              '알레르기: ${chart.allergyNotes}',
            if (chart.skinSensitivity.trim().isNotEmpty)
              '피부 민감도: ${chart.skinSensitivity}',
            if (chart.sideEffectHistory.trim().isNotEmpty)
              '부작용 이력: ${chart.sideEffectHistory}',
          ].join('\n'),
        ),
      if (chart.firstVisitFearChips.isNotEmpty)
        _detailBlock('첫 방문 인터뷰', chart.firstVisitFearChips.join(', ')),
      if (chart.revisitFeedbackChips.isNotEmpty)
        _detailBlock('재방문 인터뷰', chart.revisitFeedbackChips.join(', ')),
      if (chart.concernChips.isNotEmpty)
        _detailBlock('관심 부위', chart.concernChips.join(', ')),
      if (chart.treatmentSummary.trim().isNotEmpty)
        _detailBlock('시술 내용', chart.treatmentSummary),
      if (chart.directorInsight.trim().isNotEmpty)
        _detailBlock('원장 인사이트', chart.directorInsight),
      if (chart.beforeImageUrl != null || chart.afterImageUrl != null)
        _detailBlock(
          '사진',
          [
            if (chart.beforeImageUrl != null) 'Before 첨부됨',
            if (chart.afterImageUrl != null) 'After 첨부됨',
          ].join(' · '),
        ),
      if (review != null && review.displayText.trim().isNotEmpty) ...[
        const SizedBox(height: 8),
        const Text(
          '리뷰 스레드',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        CaseReviewInlineBlock(review: review, anonymizeNames: false),
        FutureBuilder(
          future: store.loadReviewReplies(review.id),
          builder: (context, snap) {
            final replies = snap.data ?? const [];
            if (replies.length <= 1) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '답글 히스토리 ${replies.length}건',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...replies.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '↳ ${r.body}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (onAddAfterPhoto != null)
            FilledButton.icon(
              onPressed: onAddAfterPhoto,
              style: FilledButton.styleFrom(
                backgroundColor: SoriTokens.primary,
              ),
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: const Text('After 사진 등록'),
            ),
          if (onOpenManage != null)
            OutlinedButton.icon(
              onPressed: onOpenManage,
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: const Text('차트 관리'),
            ),
          if (onEdit != null)
            OutlinedButton(
              onPressed: onEdit,
              child: const Text('차트 수정'),
            ),
          if (onConfirmOnly != null)
            FilledButton(
              onPressed: onConfirmOnly,
              style: FilledButton.styleFrom(backgroundColor: MyApp.soriPurple, foregroundColor: SoriTokens.onPrimary),
              child: const Text('방문 확인'),
            ),
          if (onShowLink != null)
            OutlinedButton.icon(
              onPressed: onShowLink,
              icon: const Icon(Icons.qr_code_2, size: 18),
              label: const Text('링크/QR'),
            ),
          if (onShowLink != null)
            TextButton(
              onPressed: () async {
                final url =
                    SoriStore.buildCustomerReviewUrl(chart.feedbackToken!);
                await Clipboard.setData(ClipboardData(text: url));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('링크 복사됨'),
                      backgroundColor: MyApp.soriPurple,
                    ),
                  );
                }
              },
              child: const Text('링크 복사'),
            ),
          if (compact && onOpenFullDetail != null)
            TextButton(
              onPressed: onOpenFullDetail,
              child: const Text('모달로 자세히 보기'),
            ),
        ],
      ),
    ];

    if (scrollController != null) {
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: children,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _detailBlock(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }
}

class _GalleryTab extends StatelessWidget {
  const _GalleryTab({
    required this.timeline,
    required this.onOpenChart,
  });

  final List<CustomerChart> timeline;
  final ValueChanged<CustomerChart> onOpenChart;

  @override
  Widget build(BuildContext context) {
    final withPhotos = timeline.where((c) {
      final b = c.beforeImageUrl?.trim() ?? '';
      final a = c.afterImageUrl?.trim() ?? '';
      return b.isNotEmpty || a.isNotEmpty;
    }).toList();

    if (withPhotos.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SoriTokens.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SoriTokens.border),
            ),
            child: const Text(
              '누적된 Before/After 사진이 없습니다.\n차트 작성 시 사진을 첨부하면 여기에 모입니다.',
            ),
          ),
        ],
      );
    }

    final episodes = groupChartsByCareName(withPhotos);
    final rows = <Widget>[
      const Text(
        '시술별 B/A',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ];
    for (final episode in episodes) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(
            '${episode.careLabel} · ${episode.visits.length}회',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
      for (final chart in episode.visits) {
        final before = chart.beforeImageUrl?.trim() ?? '';
        final after = chart.afterImageUrl?.trim() ?? '';
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Material(
              color: SoriTokens.surface,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onOpenChart(chart),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: SoriTokens.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${chart.visitNumber}회차',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            _formatChartDate(chart),
                            style: const TextStyle(
                              fontSize: 12,
                              color: SoriTokens.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: SoriTokens.textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 120,
                        child: Row(
                          children: [
                            Expanded(
                              child: _BaThumbTile(
                                label: 'Before',
                                url: before.isEmpty ? null : before,
                                accent: MyApp.soriPurple,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _BaThumbTile(
                                label: 'After',
                                url: after.isEmpty ? null : after,
                                accent: SoriTokens.primary,
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
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: rows,
    );
  }
}

class _BaThumbTile extends StatelessWidget {
  const _BaThumbTile({
    required this.label,
    required this.accent,
    this.url,
  });

  final String label;
  final Color accent;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final src = url?.trim() ?? '';
    final hasNet = src.startsWith('http://') || src.startsWith('https://');
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: const Color(0xFF111113),
            child: hasNet
                ? Image.network(
                    src,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Center(
                      child: Icon(Icons.broken_image_outlined, color: accent),
                    ),
                  )
                : Center(
                    child: Icon(Icons.image_outlined, color: accent, size: 28),
                  ),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
