import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../services/sori_store.dart';
import 'admin_chart_writer_page.dart';
import 'before_after_compare_sheet.dart';
import 'customer_link_popup.dart';
import 'membership_editor_sheet.dart';
import 'my_app.dart';

/// 원장용: 타임라인 요약 + 상세 펼침 + Before/After 갤러리.
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
  String? _expandedChartId;

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

  Future<void> _confirmVisit(CustomerChart chart) async {
    final before = widget.store.findCustomer(widget.customerId);
    final hadMembership = before?.isMembershipCustomer ?? false;
    final opened = widget.store.confirmVisit(chartId: chart.id);
    if (!mounted) return;
    final after = widget.store.findCustomer(widget.customerId);
    final remain = after?.membershipRemainingVisits ?? 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hadMembership
              ? '방문 확인 완료 · 회원권 1회 차감됐어요 (잔여 $remain회)'
              : '방문 확인 완료 · 고객 리뷰 링크가 준비됐어요',
        ),
        backgroundColor: MyApp.soriPurple,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
    await showCustomerLinkPopup(
      context,
      chart: opened,
      store: widget.store,
    );
  }

  void _toggleExpanded(String chartId) {
    setState(() {
      _expandedChartId = _expandedChartId == chartId ? null : chartId;
    });
  }

  Future<void> _openDetailSheet(CustomerChart chart) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return _ChartDetailBody(
              chart: chart,
              scrollController: scrollController,
              onEdit: chart.visitChecked
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _openWriter(chart: chart);
                    },
              onShowLink: chart.hasFeedbackLine
                  ? () {
                      Navigator.pop(ctx);
                      showCustomerLinkPopup(
                        context,
                        chart: chart,
                        store: widget.store,
                      );
                    }
                  : null,
              onConfirmOnly: chart.visitChecked
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _confirmVisit(chart);
                    },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;
    if (customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('차트 관리')),
        body: const Center(child: Text('고객 정보를 찾을 수 없습니다.')),
      );
    }

    final timeline = _timeline;
    final galleryItems = _galleryItems(timeline);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        title: Text('${customer.name} · 고객 관리'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2D3436),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: MyApp.soriPurple,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: MyApp.soriPurple,
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
            child: _Header(customer: customer),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: _QuickActionDashboard(
              onMembership: _openMembershipSheet,
              onQuickChart: () => _openWriter(forceQuickChart: true),
              onBeforeAfter: _openBeforeAfterCompare,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _TimelineTab(
                  timeline: timeline,
                  expandedChartId: _expandedChartId,
                  onToggle: _toggleExpanded,
                  onOpenDetail: _openDetailSheet,
                  onEdit: (chart) => _openWriter(chart: chart),
                  onConfirm: _confirmVisit,
                  onShowLink: (chart) => showCustomerLinkPopup(
                    context,
                    chart: chart,
                    store: widget.store,
                  ),
                ),
                _GalleryTab(items: galleryItems),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_GalleryItem> _galleryItems(List<CustomerChart> charts) {
    final items = <_GalleryItem>[];
    for (final chart in charts) {
      final dateLabel = _formatChartDate(chart);
      final care = chart.careName.isNotEmpty
          ? chart.careName
          : (chart.treatmentSummary.isNotEmpty
              ? chart.treatmentSummary
              : '시술');
      if (chart.beforeImageUrl != null &&
          chart.beforeImageUrl!.trim().isNotEmpty) {
        items.add(
          _GalleryItem(
            kind: 'Before',
            label: chart.beforeImageUrl!,
            visitLabel: '$dateLabel · ${chart.visitNumber}회차 · $care',
          ),
        );
      }
      if (chart.afterImageUrl != null &&
          chart.afterImageUrl!.trim().isNotEmpty) {
        items.add(
          _GalleryItem(
            kind: 'After',
            label: chart.afterImageUrl!,
            visitLabel: '$dateLabel · ${chart.visitNumber}회차 · $care',
          ),
        );
      }
    }
    return items;
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
  const _Header({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: MyApp.soriPurple.withValues(alpha: 0.12),
            child: Text(
              customer.name.characters.first,
              style: const TextStyle(
                color: MyApp.soriPurple,
                fontWeight: FontWeight.bold,
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
                  customer.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  customer.phone,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                if (customer.isMembershipCustomer) ...[
                  const SizedBox(height: 6),
                  Text(
                    customer.membershipBadgeLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MyApp.soriPurple,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionDashboard extends StatelessWidget {
  const _QuickActionDashboard({
    required this.onMembership,
    required this.onQuickChart,
    required this.onBeforeAfter,
  });

  final VoidCallback onMembership;
  final VoidCallback onQuickChart;
  final VoidCallback onBeforeAfter;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _QuickActionButton(
          label: '💳 회원권 등록 / 관리',
          subtitle: '횟수권 즉시 등록·수정',
          color: const Color(0xFF5B4B8A),
          onTap: onMembership,
        ),
        const SizedBox(height: 10),
        _QuickActionButton(
          label: '📝 1초 간편 차트',
          subtitle: '서명 없이 바로 차트 작성',
          color: const Color(0xFF2E7D32),
          onTap: onQuickChart,
        ),
        const SizedBox(height: 10),
        _QuickActionButton(
          label: '📸 관리 경과 비교 (B/A)',
          subtitle: '과거·오늘 사진 슬라이더 비교',
          color: const Color(0xFF1565C0),
          onTap: onBeforeAfter,
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      elevation: 1.5,
      shadowColor: color.withValues(alpha: 0.35),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineTab extends StatelessWidget {
  const _TimelineTab({
    required this.timeline,
    required this.expandedChartId,
    required this.onToggle,
    required this.onOpenDetail,
    required this.onEdit,
    required this.onConfirm,
    required this.onShowLink,
  });

  final List<CustomerChart> timeline;
  final String? expandedChartId;
  final ValueChanged<String> onToggle;
  final ValueChanged<CustomerChart> onOpenDetail;
  final ValueChanged<CustomerChart> onEdit;
  final ValueChanged<CustomerChart> onConfirm;
  final ValueChanged<CustomerChart> onShowLink;

  @override
  Widget build(BuildContext context) {
    if (timeline.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Text('아직 작성된 차트가 없습니다. 새 차트를 작성해 주세요.'),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: timeline.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              '시술 차트 타임라인',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          );
        }
        final chart = timeline[index - 1];
        final expanded = expandedChartId == chart.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _TimelineSummaryCard(
            chart: chart,
            expanded: expanded,
            onTap: () => onToggle(chart.id),
            onOpenDetail: () => onOpenDetail(chart),
            onEdit: chart.visitChecked ? null : () => onEdit(chart),
            onConfirmOnly:
                chart.visitChecked ? null : () => onConfirm(chart),
            onShowLink:
                chart.hasFeedbackLine ? () => onShowLink(chart) : null,
          ),
        );
      },
    );
  }
}

class _TimelineSummaryCard extends StatelessWidget {
  const _TimelineSummaryCard({
    required this.chart,
    required this.expanded,
    required this.onTap,
    required this.onOpenDetail,
    this.onEdit,
    this.onShowLink,
    this.onConfirmOnly,
  });

  final CustomerChart chart;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onOpenDetail;
  final VoidCallback? onEdit;
  final VoidCallback? onShowLink;
  final VoidCallback? onConfirmOnly;

  @override
  Widget build(BuildContext context) {
    final care = chart.careName.isNotEmpty
        ? chart.careName
        : (chart.treatmentSummary.isNotEmpty
            ? chart.treatmentSummary
            : '시술 기록');
    final title =
        '${_formatChartDate(chart)} (${chart.visitNumber}회차) - $care';

    return Dismissible(
      key: ValueKey('timeline_${chart.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onOpenDetail();
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: MyApp.soriPurple.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Icon(Icons.open_in_full, color: MyApp.soriPurple, size: 20),
            SizedBox(width: 8),
            Text(
              '상세 보기',
              style: TextStyle(
                color: MyApp.soriPurple,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress: onOpenDetail,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: expanded
                    ? MyApp.soriPurple.withValues(alpha: 0.45)
                    : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ),
                    if (chart.visitChecked)
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: Colors.green.shade500,
                      ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
                if (expanded) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _ChartDetailBody(
                    chart: chart,
                    compact: true,
                    onEdit: onEdit,
                    onShowLink: onShowLink,
                    onConfirmOnly: onConfirmOnly,
                    onOpenFullDetail: onOpenDetail,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartDetailBody extends StatelessWidget {
  const _ChartDetailBody({
    required this.chart,
    this.scrollController,
    this.compact = false,
    this.onEdit,
    this.onShowLink,
    this.onConfirmOnly,
    this.onOpenFullDetail,
  });

  final CustomerChart chart;
  final ScrollController? scrollController;
  final bool compact;
  final VoidCallback? onEdit;
  final VoidCallback? onShowLink;
  final VoidCallback? onConfirmOnly;
  final VoidCallback? onOpenFullDetail;

  @override
  Widget build(BuildContext context) {
    final care = chart.careName.isNotEmpty
        ? chart.careName
        : (chart.treatmentSummary.isNotEmpty
            ? chart.treatmentSummary
            : '시술 기록');

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
            if (chart.beforeImageUrl != null) 'Before: ${chart.beforeImageUrl}',
            if (chart.afterImageUrl != null) 'After: ${chart.afterImageUrl}',
          ].join('\n'),
        ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (onEdit != null)
            OutlinedButton(
              onPressed: onEdit,
              child: const Text('차트 수정'),
            ),
          if (onConfirmOnly != null)
            FilledButton(
              onPressed: onConfirmOnly,
              style: FilledButton.styleFrom(backgroundColor: MyApp.soriPurple),
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

class _GalleryItem {
  const _GalleryItem({
    required this.kind,
    required this.label,
    required this.visitLabel,
  });

  final String kind;
  final String label;
  final String visitLabel;
}

class _GalleryTab extends StatelessWidget {
  const _GalleryTab({required this.items});

  final List<_GalleryItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Text(
              '누적된 Before/After 사진이 없습니다.\n차트 작성 시 사진을 첨부하면 여기에 모입니다.',
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isBefore = item.kind == 'Before';
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isBefore
                        ? const Color(0xFFF3E8FF)
                        : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_outlined,
                        size: 36,
                        color: isBefore
                            ? MyApp.soriPurple
                            : Colors.green.shade700,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.kind,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isBefore
                              ? MyApp.soriPurple
                              : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.visitLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        );
      },
    );
  }
}
