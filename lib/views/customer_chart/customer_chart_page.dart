import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/content_candidate/content_candidate_inbox.dart';
import '../../features/visit/care_schedule_read_density.dart';
import '../../features/visit/care_start_from_schedule.dart';
import '../../models/customer.dart';
import '../../models/customer_chart.dart';
import '../../routing/sori_router.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../utils/storage_image_url.dart';
import '../admin_chart_writer_page.dart';
import '../before_after_compare_page.dart';
import '../chart_management_page.dart';
import '../smart_guide_camera_page.dart';
import '../customer_merge_wizard.dart';
import '../membership_editor_sheet.dart';
import '../request_customer_review.dart';
import '../../visit_kernel/models/care_schedule_entry.dart';
import 'chart_summary.dart';

/// 원장용 고객 차트 (U1–U4) — 타일 허브 대체. 데이터는 Store 읽기만.
class CustomerChartPage extends StatefulWidget {
  const CustomerChartPage({
    super.key,
    required this.store,
    required this.customerId,
    this.revealChartId,
    this.revealLatestResult = false,
  });

  final SoriStore store;
  final String customerId;
  final String? revealChartId;
  final bool revealLatestResult;

  @override
  State<CustomerChartPage> createState() => _CustomerChartPageState();
}

class _CustomerChartPageState extends State<CustomerChartPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    widget.store.addListener(_onStore);
    ContentCandidateInbox.instance.addListener(_onStore);
    unawaited(ContentCandidateInbox.instance.hydrate());
    if (widget.revealLatestResult) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _tabs.index = 1;
        CustomerChart? chart;
        final id = widget.revealChartId?.trim() ?? '';
        if (id.isNotEmpty) {
          chart = widget.store.findChartById(id);
        }
        chart ??= _charts.isEmpty ? null : _charts.first;
        if (chart == null) return;
        _openBeforeAfterCompare(chart: chart);
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    widget.store.removeListener(_onStore);
    ContentCandidateInbox.instance.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Customer? get _customer => widget.store.findCustomer(widget.customerId);

  List<CustomerChart> get _charts =>
      widget.store.chartsForCustomer(widget.customerId);

  Future<void> _scheduleNextCare() async {
    final customer = _customer;
    if (customer == null) return;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 28)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: '다음 방문 일정',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 14, minute: 0),
    );
    if (!mounted) return;
    final at = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 14,
      time?.minute ?? 0,
    );
    final latest = _charts.isEmpty ? null : _charts.first;
    final care = latest?.careName.trim() ?? '';
    await widget.store.addManualCareSchedule(
      scheduledAt: at,
      customerName: customer.name,
      customerId: customer.id,
      customerPhone: customer.phone,
      careLabel: care.isEmpty ? '다음 관리' : care,
    );
  }

  Future<void> _openQuickChart() async {
    final customer = _customer;
    if (customer == null) return;
    await openChartWriterForCustomer(
      context,
      store: widget.store,
      customer: customer,
      forceQuickChart: true,
    );
    if (mounted) setState(() {});
  }

  /// DESIGN LAWS: filled primary 1개 — 새 방문 기록 (간편 차트 아님).
  Future<void> _openNewVisitRecord() async {
    final customer = _customer;
    if (customer == null) return;
    await openChartWriterForCustomer(
      context,
      store: widget.store,
      customer: customer,
    );
    if (mounted) setState(() {});
  }

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
        backgroundColor: SoriTokens.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openMissingResultCapture(CustomerChart chart) async {
    final customer = _customer;
    if (customer == null) return;
    final kind = chart.needsAfterPhoto
        ? GuideCameraKind.after
        : GuideCameraKind.before;
    final result = await SmartGuideCameraPage.open(
      context,
      shopId: widget.store.shop.id,
      customerId: customer.id,
      kind: kind,
      ghostBeforeUrl:
          kind == GuideCameraKind.after ? chart.beforeImageUrl : null,
    );
    if (!mounted || result == null) return;
    if (result.kind == GuideCameraKind.before) {
      await widget.store.updateCustomerChartFields(
        chartId: chart.id,
        beforeImageUrl: result.url,
      );
    } else {
      await widget.store.patchChartAfterImage(
        chartId: chart.id,
        afterImageUrl: result.url,
      );
    }
    if (!mounted) return;
    final updated = widget.store.findChartById(chart.id) ?? chart;
    await _openBeforeAfterCompare(chart: updated);
  }

  Future<void> _enqueueContentCandidate(CustomerChart chart) async {
    final ok = await ContentCandidateInbox.instance.enqueue(chart);
    if (!mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('콘텐츠 후보함에 담았어요')),
    );
  }

  Future<void> _openBeforeAfterCompare({CustomerChart? chart}) async {
    final customer = _customer;
    if (customer == null) return;
    final charts = _charts;
    await openBeforeAfterComparePage(
      context: context,
      customerName: customer.name,
      charts: charts,
      initialChartId: chart?.id ?? (charts.isEmpty ? null : charts.first.id),
      initialCareName:
          chart?.careName ?? (charts.isEmpty ? null : charts.first.careName),
      customerId: customer.id,
      store: widget.store,
    );
  }

  void _onOverflow(String value) {
    switch (value) {
      case 'quick':
        _openQuickChart();
      case 'manage':
        _openChartManagement();
      case 'membership':
        _openMembershipSheet();
      case 'ba':
        _openBeforeAfterCompare();
      case 'review':
        final c = _customer;
        if (c == null) return;
        requestCustomerReviewWithQr(
          context,
          store: widget.store,
          customer: c,
        );
      case 'merge':
        final customer = _customer;
        if (customer == null) return;
        pickCustomersForMerge(
          context: context,
          store: widget.store,
          seed: customer,
        ).then((selected) async {
          if (selected != null && selected.length >= 2 && mounted) {
            await showCustomerMergeWizard(
              context: context,
              store: widget.store,
              selected: selected,
            );
          }
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;
    if (customer == null) {
      return Scaffold(
        backgroundColor: SoriTokens.background,
        appBar: AppBar(
          title: const Text('고객 차트'),
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
        ),
        body: const Center(child: Text('고객 정보를 찾을 수 없습니다.')),
      );
    }

    final charts = _charts;
    final summary = ChartSummary.from(
      charts,
      remainingCredit: customer.membershipRemainingVisits,
    );

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
          PopupMenuButton<String>(
            tooltip: '더보기',
            onSelected: _onOverflow,
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'quick', child: Text('1초 간편 차트')),
              PopupMenuItem(value: 'manage', child: Text('차트 관리')),
              PopupMenuItem(value: 'membership', child: Text('회원권 관리')),
              PopupMenuItem(value: 'ba', child: Text('B/A 비교')),
              PopupMenuItem(value: 'review', child: Text('후기 요청')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'merge', child: Text('중복 계정 병합')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: SoriTokens.brand,
          unselectedLabelColor: const Color(0xFF9CA3AF),
          indicatorColor: SoriTokens.brand,
          indicatorWeight: 2,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: '타임라인'),
            Tab(text: '사진'),
            Tab(text: '결제'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewVisitRecord,
        backgroundColor: SoriTokens.brand,
        foregroundColor: SoriTokens.onBrand,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          '새 방문 기록',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _SummaryBar(summary: summary),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _NextCareBanner(
              entry: CareScheduleReadDensity.nextUpcomingForCustomer(
                widget.store.careScheduleEntries,
                customerId: widget.customerId,
              ),
              onStart: (entry) {
                CareStartFromSchedule.begin(
                  context: context,
                  store: widget.store,
                  entry: entry,
                );
              },
              onScheduleNext: _scheduleNextCare,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: _AlertChips(charts: charts),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _TimelineTab(
                  charts: charts,
                  onTapChart: (c) => _openChartManagement(chartId: c.id),
                ),
                _PhotoTab(
                  charts: charts,
                  onTapChart: (c) => _openBeforeAfterCompare(chart: c),
                  onCaptureMissing: _openMissingResultCapture,
                  contentCandidateIds:
                      ContentCandidateInbox.instance.entries.keys.toSet(),
                  onMakeContentCandidate: _enqueueContentCandidate,
                ),
                _PaymentTab(
                  charts: charts,
                  summary: summary,
                  onTapChart: (c) => _openChartManagement(chartId: c.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.summary});

  final ChartSummary summary;

  @override
  Widget build(BuildContext context) {
    final remain = summary.remainingCredit;
    final days = summary.daysSinceLast;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _SummaryCell(
                value: '${summary.visitCount}',
                label: '누적 방문',
              ),
              _SummaryCell(
                value: summary.totalPaid > 0
                    ? _formatWon(summary.totalPaid)
                    : '—',
                label: '누적 결제',
              ),
              _SummaryCell(
                value: (remain != null && remain > 0) ? '$remain회' : '—',
                label: '잔여 선불권',
              ),
              _SummaryCell(
                value: days == null ? '—' : (days == 0 ? 'D+0' : 'D+$days'),
                label: '최근 방문',
              ),
            ],
          ),
          if (summary.latestChangeLine != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '최근 시술  ${summary.latestChangeLine}',
                key: const Key('customer-chart-latest-change'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SoriTokens.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatWon(int amount) {
    final digits = amount.toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final fromEnd = digits.length - i;
      buf.write(digits[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return '${buf}원';
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextCareBanner extends StatelessWidget {
  const _NextCareBanner({
    required this.entry,
    required this.onStart,
    this.onScheduleNext,
  });

  final CareScheduleEntry? entry;
  final ValueChanged<CareScheduleEntry> onStart;
  final VoidCallback? onScheduleNext;

  @override
  Widget build(BuildContext context) {
    final next = entry;
    if (next == null) {
      if (onScheduleNext == null) return const SizedBox.shrink();
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          key: const Key('customer-chart-schedule-next'),
          onPressed: onScheduleNext,
          child: const Text('다음 케어 일정 잡기'),
        ),
      );
    }
    final care = next.careLabel.trim();
    final when =
        '${next.scheduledAt.month}/${next.scheduledAt.day} ${CareScheduleReadDensity.timeLabel(next.scheduledAt)}';
    return Material(
      key: const Key('customer-chart-next-care'),
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                care.isEmpty ? '다음 케어  $when' : '다음 케어  $when  ·  $care',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: SoriTokens.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => onStart(next),
              style: FilledButton.styleFrom(
                backgroundColor: SoriTokens.semanticGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '케어 시작',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// U1: 알러지·주의(부작용)만. VIP 필드는 고객 모델에 없어 제외.
class _AlertChips extends StatelessWidget {
  const _AlertChips({required this.charts});

  final List<CustomerChart> charts;

  @override
  Widget build(BuildContext context) {
    String allergy = '';
    String caution = '';
    for (final c in charts) {
      if (allergy.isEmpty && c.allergyNotes.trim().isNotEmpty) {
        allergy = c.allergyNotes.trim();
      }
      if (caution.isEmpty && c.sideEffectHistory.trim().isNotEmpty) {
        caution = c.sideEffectHistory.trim();
      }
      if (allergy.isNotEmpty && caution.isNotEmpty) break;
    }
    if (allergy.isEmpty && caution.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (allergy.isNotEmpty)
          _AlertChip(label: '알러지 · $allergy'),
        if (caution.isNotEmpty)
          _AlertChip(label: '주의 · $caution'),
      ],
    );
  }
}

class _AlertChip extends StatelessWidget {
  const _AlertChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final text = label.length > 36 ? '${label.substring(0, 36)}…' : label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SoriTokens.systemRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: SoriTokens.systemRed,
        ),
      ),
    );
  }
}

class _TimelineTab extends StatelessWidget {
  const _TimelineTab({
    required this.charts,
    required this.onTapChart,
  });

  final List<CustomerChart> charts;
  final ValueChanged<CustomerChart> onTapChart;

  @override
  Widget build(BuildContext context) {
    if (charts.isEmpty) {
      return const Center(
        child: Text(
          '아직 방문 기록이 없습니다',
          style: TextStyle(color: Color(0xFF9CA3AF)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: charts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemBuilder: (context, index) {
        final chart = charts[index];
        return _VisitRoundCard(
          chart: chart,
          onTap: () => onTapChart(chart),
        );
      },
    );
  }
}

class _VisitRoundCard extends StatelessWidget {
  const _VisitRoundCard({
    required this.chart,
    required this.onTap,
  });

  final CustomerChart chart;
  final VoidCallback onTap;

  /// 「고객 상태 · 대화」 = [CustomerChart.treatmentSummary]. 첫 줄 40자.
  static String? _memoLine(CustomerChart chart) {
    final raw = chart.treatmentSummary.trim();
    if (raw.isEmpty) return null;
    final first = raw.split(RegExp(r'\r?\n')).first.trim();
    if (first.isEmpty) return null;
    if (first.length <= 40) return first;
    return '${first.substring(0, 40)}…';
  }

  @override
  Widget build(BuildContext context) {
    final date = chart.createdAt ?? chart.visitCheckedAt;
    final dateLabel = date == null
        ? '날짜 없음'
        : '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    final care =
        chart.careName.trim().isEmpty ? '시술명 없음' : chart.careName.trim();
    final memo = _memoLine(chart);
    // 금액: 차트 row에 금액 컬럼 없음 → 줄 자체 숨김 (스펙: 0/null 표기 금지).

    return Material(
      color: SoriTokens.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _VisitThumbStrip(
                beforeUrl: chart.beforeImageUrl,
                afterUrl: chart.afterImageUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 회차는 이 줄에만 (부제/시술명에 중복 금지 — 문제 #2).
                    Text(
                      '$dateLabel · ${chart.visitNumber}회차',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      care,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: SoriTokens.textPrimary,
                      ),
                    ),
                    if (memo != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        memo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Before/After 최대 2장. 없으면 빈 박스 대신 아이콘 + 「사진 없음」.
class _VisitThumbStrip extends StatelessWidget {
  const _VisitThumbStrip({
    required this.beforeUrl,
    required this.afterUrl,
  });

  final String? beforeUrl;
  final String? afterUrl;

  static const double _size = 52;

  @override
  Widget build(BuildContext context) {
    final urls = <String>[
      for (final raw in [beforeUrl, afterUrl])
        if (StorageImageUrl.resolve(raw) case final u?) u,
    ];

    if (urls.isEmpty) {
      return SizedBox(
        width: _size * 2 + 4,
        height: _size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: 18,
                color: Color(0xFF9CA3AF),
              ),
              SizedBox(height: 2),
              Text(
                '사진 없음',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < urls.length && i < 2; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          _ThumbTile(url: urls[i]),
        ],
      ],
    );
  }
}

class _ThumbTile extends StatelessWidget {
  const _ThumbTile({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: _VisitThumbStrip._size,
        height: _VisitThumbStrip._size,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, _) => const ColoredBox(
            color: Color(0xFFF3F4F6),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (_, _, _) => const ColoredBox(
            color: Color(0xFFF3F4F6),
            child: Icon(
              Icons.broken_image_outlined,
              size: 18,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ),
      ),
    );
  }
}

/// U4 사진 탭 — 회차별 before/after 한 줄. 부위 세트 필터 없음.
class _PhotoTab extends StatelessWidget {
  const _PhotoTab({
    required this.charts,
    required this.onTapChart,
    required this.onCaptureMissing,
    required this.contentCandidateIds,
    required this.onMakeContentCandidate,
  });

  final List<CustomerChart> charts;
  final ValueChanged<CustomerChart> onTapChart;
  final ValueChanged<CustomerChart> onCaptureMissing;
  final Set<String> contentCandidateIds;
  final ValueChanged<CustomerChart> onMakeContentCandidate;

  static List<CustomerChart> _chronological(List<CustomerChart> source) {
    final list = List<CustomerChart>.from(source);
    list.sort((a, b) {
      final da = a.createdAt ?? a.visitCheckedAt;
      final db = b.createdAt ?? b.visitCheckedAt;
      if (da == null && db == null) {
        return a.visitNumber.compareTo(b.visitNumber);
      }
      if (da == null) return 1;
      if (db == null) return -1;
      final byDate = da.compareTo(db);
      if (byDate != 0) return byDate;
      return a.visitNumber.compareTo(b.visitNumber);
    });
    return list;
  }

  static String _dateLabel(CustomerChart chart) {
    final date = chart.createdAt ?? chart.visitCheckedAt;
    if (date == null) return '날짜 없음';
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (charts.isEmpty) {
      return const Center(
        child: Text(
          '아직 방문 기록이 없습니다',
          style: TextStyle(color: Color(0xFF9CA3AF)),
        ),
      );
    }

    final ordered = _chronological(charts);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: ordered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemBuilder: (context, index) {
        final chart = ordered[index];
        final care = chart.careName.trim().isEmpty
            ? '시술명 없음'
            : chart.careName.trim();
        final comparable = chart.hasBeforeImage && chart.hasAfterImage;
        return Material(
          key: Key('customer-chart-photo-row-${chart.id}'),
          color: SoriTokens.surface,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => onTapChart(chart),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_dateLabel(chart)} · ${chart.visitNumber}회차 · $care',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _PhotoBaRow(
                        beforeUrl: chart.beforeImageUrl,
                        afterUrl: chart.afterImageUrl,
                      ),
                    ],
                  ),
                ),
                if (!comparable) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      key: Key('customer-chart-photo-capture-${chart.id}'),
                      onPressed: () => onCaptureMissing(chart),
                      child: Text(
                        chart.needsAfterPhoto ? 'After 촬영' : '결과 촬영',
                      ),
                    ),
                  ),
                ],
                if (comparable &&
                    ContentCandidateInbox.isEligible(chart) &&
                    !contentCandidateIds.contains(chart.id)) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      key: Key(
                        'customer-chart-content-candidate-${chart.id}',
                      ),
                      onPressed: () => onMakeContentCandidate(chart),
                      child: const Text('콘텐츠 후보로 만들기'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PhotoBaRow extends StatelessWidget {
  const _PhotoBaRow({
    required this.beforeUrl,
    required this.afterUrl,
  });

  final String? beforeUrl;
  final String? afterUrl;

  static const double _h = 120;

  @override
  Widget build(BuildContext context) {
    final before = StorageImageUrl.resolve(beforeUrl);
    final after = StorageImageUrl.resolve(afterUrl);
    if (before == null && after == null) {
      return SizedBox(
        height: _h,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.image_not_supported_outlined,
                  size: 22,
                  color: Color(0xFF9CA3AF),
                ),
                SizedBox(height: 4),
                Text(
                  '사진 없음',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(child: _PhotoCell(label: 'Before', url: before)),
        const SizedBox(width: 8),
        Expanded(child: _PhotoCell(label: 'After', url: after)),
      ],
    );
  }
}

class _PhotoCell extends StatelessWidget {
  const _PhotoCell({required this.label, required this.url});

  final String label;
  final String? url;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: _PhotoBaRow._h - 18,
            child: url == null
                ? const ColoredBox(
                    color: Color(0xFFF3F4F6),
                    child: Center(
                      child: Text(
                        '없음',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: url!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (_, _) => const ColoredBox(
                      color: Color(0xFFF3F4F6),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (_, _, _) => const ColoredBox(
                      color: Color(0xFFF3F4F6),
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// U4 결제 탭 — 차트 row 원장 + 상단 누적·잔여. 새 쿼리 없음.
class _PaymentTab extends StatelessWidget {
  const _PaymentTab({
    required this.charts,
    required this.summary,
    required this.onTapChart,
  });

  final List<CustomerChart> charts;
  final ChartSummary summary;
  final ValueChanged<CustomerChart> onTapChart;

  static String _dateLabel(CustomerChart chart) {
    final date = chart.createdAt ?? chart.visitCheckedAt;
    if (date == null) return '날짜 없음';
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final remain = summary.remainingCredit;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: SoriTokens.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '누적 결제',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary.totalPaid > 0
                          ? _SummaryBar._formatWon(summary.totalPaid)
                          : '—',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: SoriTokens.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '잔여 선불권',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (remain != null && remain > 0) ? '$remain회' : '—',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: SoriTokens.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (charts.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Center(
              child: Text(
                '결제·방문 기록이 없습니다',
                style: TextStyle(color: Color(0xFF9CA3AF)),
              ),
            ),
          )
        else
          ...charts.map((chart) {
            final care = chart.careName.trim().isEmpty
                ? '시술명 없음'
                : chart.careName.trim();
            return Material(
              color: SoriTokens.surface,
              child: InkWell(
                onTap: () => onTapChart(chart),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_dateLabel(chart)} · ${chart.visitNumber}회차',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              care,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: SoriTokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              chart.visitChecked
                                  ? '선불권 차감됨'
                                  : '선불권 미차감',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: chart.visitChecked
                                    ? SoriTokens.textPrimary
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF9CA3AF),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
