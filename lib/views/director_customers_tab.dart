import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/customer.dart';
import '../services/sori_store.dart';
import '../routing/sori_router.dart';
import '../theme/sori_tokens.dart';
import '../widgets/sori_card.dart';
import '../widgets/today_care_schedule_panel.dart';
import 'add_customer_sheet.dart';

enum _CustomerSort { recentVisit, nameAsc, chartNo }

/// 원장 모드 [고객] 탭 — CRM 대시보드 (초성검색·정렬·집중케어).
class DirectorCustomersTab extends StatefulWidget {
  const DirectorCustomersTab({super.key, required this.store});

  final SoriStore store;

  @override
  State<DirectorCustomersTab> createState() => _DirectorCustomersTabState();
}

class _DirectorCustomersTabState extends State<DirectorCustomersTab>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late final TabController _tabController;
  String _query = '';
  _CustomerSort _sort = _CustomerSort.recentVisit;

  static const _dormantDays = 90;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    widget.store.addListener(_onStore);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  DateTime _lastVisitOf(Customer c) {
    final chart = widget.store.latestChart(c.id);
    return chart?.visitCheckedAt ??
        chart?.feedbackLineOpenedAt ??
        chart?.createdAt ??
        c.lastTreatmentDate;
  }

  int _daysSinceVisit(Customer c) {
    final last = _lastVisitOf(c);
    final today = DateTime.now();
    final a = DateTime(last.year, last.month, last.day);
    final b = DateTime(today.year, today.month, today.day);
    return b.difference(a).inDays;
  }

  bool _isDormant(Customer c) => _daysSinceVisit(c) >= _dormantDays;

  int _chartNumberOf(Customer c) {
    final charts = widget.store.chartsForCustomer(c.id);
    if (charts.isEmpty) return 0;
    var maxNo = 0;
    for (final ch in charts) {
      final parsed = int.tryParse(ch.customChartNo?.trim() ?? '');
      final n = parsed ?? ch.visitNumber;
      if (n > maxNo) maxNo = n;
    }
    return maxNo;
  }

  List<Customer> _baseFiltered() {
    return widget.store.searchCustomers(_query);
  }

  List<Customer> _listForTab({required bool focusCare}) {
    var list = _baseFiltered();
    if (focusCare) {
      list = list.where(_isDormant).toList();
    }
    list = List<Customer>.of(list);
    switch (_sort) {
      case _CustomerSort.recentVisit:
        list.sort((a, b) => _lastVisitOf(b).compareTo(_lastVisitOf(a)));
      case _CustomerSort.nameAsc:
        list.sort((a, b) => a.name.compareTo(b.name));
      case _CustomerSort.chartNo:
        list.sort((a, b) {
          final cmp = _chartNumberOf(b).compareTo(_chartNumberOf(a));
          if (cmp != 0) return cmp;
          return a.name.compareTo(b.name);
        });
    }
    return list;
  }

  Future<void> _addCustomer() async {
    await showAddCustomerSheet(context, store: widget.store);
  }

  void _openDetail(Customer c) {
    context.push(AppPaths.customerDetail(c.id));
  }

  void _pickSort() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '정렬',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              ..._CustomerSort.values.map((s) {
                final label = switch (s) {
                  _CustomerSort.recentVisit => '최근 방문순',
                  _CustomerSort.nameAsc => '가나다순',
                  _CustomerSort.chartNo => '차트 번호순',
                };
                return ListTile(
                  title: Text(label),
                  trailing: _sort == s
                      ? const Icon(Icons.check, color: SoriTokens.primary)
                      : null,
                  onTap: () {
                    setState(() => _sort = s);
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.store.customers;
    final isEmptyDb = all.isEmpty;
    final allList = _listForTab(focusCare: false);
    final focusList = _listForTab(focusCare: true);
    final focusCount = all.where(_isDormant).length;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TodayCareSchedulePanel(store: widget.store),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            child: Row(
              children: [
                const Spacer(),
                if (!isEmptyDb)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '${all.length}명',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: '정렬',
                  onPressed: isEmptyDb ? null : _pickSort,
                  icon: const Icon(Icons.filter_list_rounded),
                  color: SoriTokens.primary,
                ),
                IconButton(
                  tooltip: '고객 추가',
                  onPressed: _addCustomer,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  color: SoriTokens.primary,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              enabled: !isEmptyDb,
              decoration: InputDecoration(
                hintText: '이름 · 초성(ㅎㄱㄷ) · 전화번호',
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
          Material(
            color: Colors.transparent,
            child: TabBar(
              controller: _tabController,
              labelColor: SoriTokens.primary,
              unselectedLabelColor: SoriTokens.textSecondary,
              indicatorColor: SoriTokens.primary,
              tabs: [
                const Tab(text: '전체 고객'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥 집중 케어'),
                      if (focusCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$focusCount',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFC62828),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isEmptyDb
                ? _EmptyCustomersState(onAdd: _addCustomer)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _CustomerListBody(
                        list: allList,
                        emptyLabel: '검색 결과가 없습니다',
                        formatDate: _formatDate,
                        lastVisitOf: _lastVisitOf,
                        daysSince: _daysSinceVisit,
                        showDormantHint: false,
                        onAdd: _addCustomer,
                        onOpen: _openDetail,
                      ),
                      _CustomerListBody(
                        list: focusList,
                        emptyLabel: '90일 이상 미방문 고객이 없습니다',
                        formatDate: _formatDate,
                        lastVisitOf: _lastVisitOf,
                        daysSince: _daysSinceVisit,
                        showDormantHint: true,
                        onAdd: _addCustomer,
                        onOpen: _openDetail,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CustomerListBody extends StatelessWidget {
  const _CustomerListBody({
    required this.list,
    required this.emptyLabel,
    required this.formatDate,
    required this.lastVisitOf,
    required this.daysSince,
    required this.showDormantHint,
    required this.onAdd,
    required this.onOpen,
  });

  final List<Customer> list;
  final String emptyLabel;
  final String Function(DateTime) formatDate;
  final DateTime Function(Customer) lastVisitOf;
  final int Function(Customer) daysSince;
  final bool showDormantHint;
  final VoidCallback onAdd;
  final ValueChanged<Customer> onOpen;

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emptyLabel,
              style: const TextStyle(
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('새 고객 등록'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      itemCount: list.length + (showDormantHint ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (showDormantHint && index == 0) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: const Text(
              '마지막 방문 기준 90일 이상 미방문 고객입니다. 케어 리마인드·티켓팅 제안 타이밍을 확인해 주세요.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8D6E00),
              ),
            ),
          );
        }
        final c = list[showDormantHint ? index - 1 : index];
        final remain = c.membershipRemainingVisits;
        final hasMembership = c.isMembershipCustomer;
        final ticketingUrgent = hasMembership && remain >= 1 && remain <= 2;
        return _DenseCustomerTile(
          name: c.name,
          phone: c.phone,
          lastVisitLabel: formatDate(lastVisitOf(c)),
          dormantDays: daysSince(c),
          remainLabel: hasMembership ? '잔여 $remain회' : '회원권 미등록',
          remainUrgent: ticketingUrgent,
          remainWarn: hasMembership && c.isMembershipLow && !ticketingUrgent,
          onTap: () => onOpen(c),
        );
      },
    );
  }
}

class _EmptyCustomersState extends StatelessWidget {
  const _EmptyCustomersState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: SoriTokens.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 36,
                color: SoriTokens.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '등록된 고객이 없습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: SoriTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '첫 고객을 등록하면 차트 작성과 리뷰 요청을\n바로 시작할 수 있어요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: SoriTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: SoriTokens.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '[ + 첫 고객 등록하기 ]',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DenseCustomerTile extends StatelessWidget {
  const _DenseCustomerTile({
    required this.name,
    required this.phone,
    required this.lastVisitLabel,
    required this.remainLabel,
    required this.onTap,
    this.dormantDays = 0,
    this.remainUrgent = false,
    this.remainWarn = false,
  });

  final String name;
  final String phone;
  final String lastVisitLabel;
  final int dormantDays;
  final String remainLabel;
  final bool remainUrgent;
  final bool remainWarn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badgeBg = remainUrgent
        ? const Color(0xFFFFEBEE)
        : (remainWarn ? SoriTokens.warningBg : SoriTokens.primarySoft);
    final badgeFg = remainUrgent
        ? const Color(0xFFC62828)
        : (remainWarn ? SoriTokens.warningText : SoriTokens.primary);

    return SoriCard(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: SoriTokens.primarySoft,
            child: Text(
              name.characters.first,
              style: const TextStyle(
                color: SoriTokens.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  phone,
                  style: const TextStyle(
                    fontSize: 13,
                    color: SoriTokens.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.event_rounded,
                      size: 14,
                      color: SoriTokens.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        dormantDays >= 90
                            ? '최근 $lastVisitLabel · $dormantDays일 전'
                            : '최근 $lastVisitLabel',
                        style: TextStyle(
                          fontSize: 12,
                          color: dormantDays >= 90
                              ? const Color(0xFFC62828)
                              : SoriTokens.textSecondary,
                          fontWeight: dormantDays >= 90
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: remainUrgent
                      ? Border.all(color: const Color(0xFFEF9A9A))
                      : null,
                ),
                child: Text(
                  remainLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: badgeFg,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: SoriTokens.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
