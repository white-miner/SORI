import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../models/home_care_prescriptions.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/sori_logo.dart';
import 'care_history_detail_page.dart';
import 'care_viewer_calendar_page.dart';
import 'ikea_review_composer_page.dart';

/// 고객 모드 전용 케어 탭 — 미션·가족 스위처·처방 다이어리.
class CustomerCareTab extends StatefulWidget {
  const CustomerCareTab({super.key, required this.store});

  final SoriStore store;

  @override
  State<CustomerCareTab> createState() => _CustomerCareTabState();
}

class _CustomerCareTabState extends State<CustomerCareTab> {
  SoriStore get store => widget.store;

  /// null = 본인, 그 외 = 열람 중인 가족 customerId.
  String? _viewingCustomerId;

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

  String? get _selfCustomerId => store.session?.customerId;

  String? get _activeCustomerId => _viewingCustomerId ?? _selfCustomerId;

  List<Customer> _familyMembers() {
    final phone = store.session?.phone ?? '';
    final selfId = _selfCustomerId;
    return store
        .familyCustomersForGuardianPhone(phone)
        .where((c) => c.id != selfId)
        .toList();
  }

  /// 시술일 기준 0~2일차만 미션 활성.
  ({CustomerChart chart, int dayOffset, int checkedCount})? _activeMission(
    String? customerId,
  ) {
    if (customerId == null) return null;
    final charts = store.chartsForCustomer(customerId);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final chart in charts) {
      if (chart.homeCarePrescriptions.isEmpty) continue;
      final visit = chart.visitCheckedAt ?? chart.createdAt;
      if (visit == null) continue;
      final start = DateTime(visit.year, visit.month, visit.day);
      final offset = today.difference(start).inDays;
      if (offset < 0 || offset > 2) continue;
      final checks =
          CustomerChart.normalizeMissionChecks(chart.homeCareMissionChecks);
      final checked = checks.where((e) => e).length;
      return (chart: chart, dayOffset: offset, checkedCount: checked);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final session = store.session!;
    final selfId = _selfCustomerId;
    final activeId = _activeCustomerId;
    final customer =
        activeId == null ? null : store.findCustomer(activeId);
    final selfCustomer =
        selfId == null ? null : store.findCustomer(selfId);
    final charts = activeId == null
        ? <CustomerChart>[]
        : store.chartsForCustomer(activeId).toList()
      ..sort((a, b) => b.visitNumber.compareTo(a.visitNumber));
    final latest = charts.isEmpty ? null : charts.first;
    final selfName = session.name.trim().isEmpty
        ? (selfCustomer?.name ?? '나')
        : session.name.trim();
    final activeName = customer?.name ?? selfName;
    final family = _familyMembers();
    final shopName = store.shop.name.trim().isEmpty ? 'SORI 샵' : store.shop.name;
    final lastVisit = latest?.visitCheckedAt ??
        latest?.createdAt ??
        customer?.lastTreatmentDate;
    final nextVisit = lastVisit?.add(const Duration(days: 28));
    final careName = latest == null
        ? (customer?.membershipServiceName.isNotEmpty == true
            ? customer!.membershipServiceName
            : '진행 중인 케어')
        : (latest.careName.isNotEmpty
            ? latest.careName
            : (latest.treatmentSummary.isNotEmpty
                ? latest.treatmentSummary
                : '케어'));
    final visitNo = latest?.visitNumber ?? customer?.membershipUsedVisits ?? 0;
    final mission = _activeMission(activeId);
    final directives = HomecareDictionary.resolveDirectives(
      latest?.homeCarePrescriptions ?? const [],
    );
    final viewingFamily = _viewingCustomerId != null;

    return ColoredBox(
      color: SoriTokens.background,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _ProfileHeaderRow(
              selfName: selfName,
              selfSelected: !viewingFamily,
              family: family,
              selectedFamilyId: _viewingCustomerId,
              onSelectSelf: () => setState(() => _viewingCustomerId = null),
              onSelectFamily: (id) =>
                  setState(() => _viewingCustomerId = id),
              onCalendar: () {
                final id = activeId;
                if (id == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('고객 정보가 연결되어 있지 않아요'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CareViewerCalendarPage(
                      store: store,
                      customerId: id,
                    ),
                  ),
                );
              },
            ),
            if (viewingFamily) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: SoriTokens.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '보호자 열람 동의로 $activeName 님의 케어를 보고 있어요',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: SoriTokens.primary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (mission != null) ...[
              _HomeCareMissionCard(
                checkedCount: mission.checkedCount,
                checks: CustomerChart.normalizeMissionChecks(
                  mission.chart.homeCareMissionChecks,
                ),
                dayOffset: mission.dayOffset,
                directives: HomecareDictionary.resolveDirectives(
                  mission.chart.homeCarePrescriptions,
                ),
                onToggle: (index, value) {
                  store.setHomeCareMissionCheck(
                    chartId: mission.chart.id,
                    dayIndex: index,
                    checked: value,
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
            _AiReportCard(
              shopName: shopName,
              lastVisit: lastVisit,
              insight: latest?.directorInsight ?? '',
              directives: directives,
              onDetail: () {
                if (latest == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('아직 AI 리포트가 없어요'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _AiReportDetailPage(
                      shopName: shopName,
                      chart: latest,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _CareSummaryCard(
              careName: careName,
              visitNo: visitNo,
              nextVisit: nextVisit,
              remaining: customer?.membershipRemainingVisits ?? 0,
              onMore: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CareHistoryDetailPage(
                      store: store,
                      customerId: activeId,
                    ),
                  ),
                );
              },
            ),
            if (latest != null &&
                latest.hasFeedbackLine &&
                !viewingFamily) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          backgroundColor: SoriTokens.background,
                          appBar: AppBar(
                            title: const Text('리뷰 작성'),
                            backgroundColor: SoriTokens.surface,
                            foregroundColor: SoriTokens.textPrimary,
                            elevation: 0,
                          ),
                          body: IkeaReviewComposerPage(
                            store: store,
                            chart: latest,
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text(
                    '리뷰 작성하기',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SoriTokens.primary,
                    side: const BorderSide(color: SoriTokens.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeCareMissionCard extends StatelessWidget {
  const _HomeCareMissionCard({
    required this.checkedCount,
    required this.checks,
    required this.dayOffset,
    required this.directives,
    required this.onToggle,
  });

  final int checkedCount;
  final List<bool> checks;
  final int dayOffset;
  final List<String> directives;
  final void Function(int index, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    final progress = checkedCount / 3.0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SoriTokens.border),
        boxShadow: SoriTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '원장님의 홈케어 처방 미션 ($checkedCount/3일)',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: SoriTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '시술 후 ${dayOffset + 1}일차 · 가장 중요한 3일 케어',
            style: const TextStyle(fontSize: 12, color: SoriTokens.textSecondary),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: SoriTokens.surfaceElevated,
                  color: SoriTokens.primary,
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < 3; i++)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: checks[i],
              onChanged: (v) => onToggle(i, v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: SoriTokens.primary,
              title: Text(
                '${i + 1}일차 홈케어 실천',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: SoriTokens.textPrimary,
                ),
              ),
              subtitle: Text(
                i < directives.length
                    ? directives[i]
                    : (directives.isNotEmpty
                        ? directives.first
                        : '처방 내용을 실천해 주세요'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: SoriTokens.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileHeaderRow extends StatelessWidget {
  const _ProfileHeaderRow({
    required this.selfName,
    required this.selfSelected,
    required this.family,
    required this.selectedFamilyId,
    required this.onSelectSelf,
    required this.onSelectFamily,
    required this.onCalendar,
  });

  final String selfName;
  final bool selfSelected;
  final List<Customer> family;
  final String? selectedFamilyId;
  final VoidCallback onSelectSelf;
  final ValueChanged<String> onSelectFamily;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                InkWell(
                  onTap: onSelectSelf,
                  borderRadius: BorderRadius.circular(12),
                  child: _ProfileChip(
                    label: selfName,
                    selected: selfSelected,
                  ),
                ),
                ...family.map((c) {
                  final selected = selectedFamilyId == c.id;
                  return Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: InkWell(
                      onTap: () => onSelectFamily(c.id),
                      borderRadius: BorderRadius.circular(12),
                      child: _ProfileChip(
                        label: c.name,
                        selected: selected,
                      ),
                    ),
                  );
                }),
                if (family.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: _ProfileChip(
                      label: '가족',
                      selected: false,
                      muted: true,
                    ),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: '캘린더',
          onPressed: onCalendar,
          icon: const Icon(Icons.calendar_month_outlined),
          color: SoriTokens.textPrimary,
        ),
      ],
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({
    required this.label,
    required this.selected,
    this.muted = false,
  });

  final String label;
  final bool selected;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor:
              selected ? SoriTokens.primarySoft : SoriTokens.surfaceElevated,
          child: muted
              ? const Icon(Icons.person_outline, color: SoriTokens.textSecondary, size: 22)
              : const Padding(
                  padding: EdgeInsets.all(8),
                  child: Opacity(
                    opacity: 0.9,
                    child: SoriLogo(width: 28, height: 28),
                  ),
                ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 56,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? SoriTokens.primary : SoriTokens.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _AiReportCard extends StatelessWidget {
  const _AiReportCard({
    required this.shopName,
    required this.lastVisit,
    required this.insight,
    required this.directives,
    required this.onDetail,
  });

  final String shopName;
  final DateTime? lastVisit;
  final String insight;
  final List<String> directives;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SoriTokens.border),
        boxShadow: SoriTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: SoriTokens.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  directives.isEmpty ? '홈케어 대기' : '홈케어 진행중',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: SoriTokens.success,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.auto_awesome, color: SoriTokens.primary, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            shopName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: SoriTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lastVisit == null
                ? '최근 방문 기록 없음'
                : '최근 방문 ${_fmt(lastVisit!)}',
            style: const TextStyle(fontSize: 12, color: SoriTokens.textSecondary),
          ),
          if (insight.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              insight.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.4, color: SoriTokens.textPrimary),
            ),
          ],
          if (directives.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...directives.take(2).map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('· ', style: TextStyle(fontWeight: FontWeight.w800, color: SoriTokens.textPrimary)),
                        Expanded(
                          child: Text(
                            d,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: SoriTokens.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onDetail,
              child: const Text(
                'AI 리포트 상세보기',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: SoriTokens.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CareSummaryCard extends StatelessWidget {
  const _CareSummaryCard({
    required this.careName,
    required this.visitNo,
    required this.nextVisit,
    required this.remaining,
    required this.onMore,
  });

  final String careName;
  final int visitNo;
  final DateTime? nextVisit;
  final int remaining;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SoriTokens.border),
        boxShadow: SoriTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            careName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: SoriTokens.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            [
              if (visitNo > 0) '$visitNo회차',
              if (remaining > 0) '잔여 $remaining회',
              if (nextVisit != null) '다음 권장 ${_fmt(nextVisit!)}',
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: SoriTokens.textSecondary),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onMore,
              child: const Text(
                '케어내역 더보기',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: SoriTokens.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiReportDetailPage extends StatelessWidget {
  const _AiReportDetailPage({
    required this.shopName,
    required this.chart,
  });

  final String shopName;
  final CustomerChart chart;

  @override
  Widget build(BuildContext context) {
    final directives = HomecareDictionary.resolveDirectives(
      chart.homeCarePrescriptions,
    );
    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: const Text('AI 리포트 상세'),
        backgroundColor: SoriTokens.surface,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            shopName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: SoriTokens.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            chart.careName.isNotEmpty ? chart.careName : '케어',
            style: const TextStyle(color: SoriTokens.textSecondary),
          ),
          const SizedBox(height: 16),
          if (chart.directorInsight.trim().isNotEmpty) ...[
            const Text(
              '원장 인사이트',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(chart.directorInsight.trim(), style: const TextStyle(height: 1.45, color: SoriTokens.textPrimary)),
            const SizedBox(height: 18),
          ],
          const Text(
            '홈케어 처방',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (directives.isEmpty)
            Text(
              '등록된 홈케어 처방이 없어요',
              style: const TextStyle(color: SoriTokens.textSecondary),
            )
          else
            ...directives.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SoriTokens.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(d, style: const TextStyle(height: 1.45, fontSize: 13, color: SoriTokens.textPrimary)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _fmt(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
