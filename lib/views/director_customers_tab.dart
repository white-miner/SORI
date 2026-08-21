import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/customer.dart';
import '../services/sori_store.dart';
import '../routing/sori_router.dart';
import '../theme/sori_tokens.dart';
import '../widgets/sori_card.dart';
import '../widgets/today_care_schedule_panel.dart';
import 'add_customer_sheet.dart';
import 'request_customer_review.dart';

enum _CustomerSort { recentVisit, nameAsc, chartNo, dormantDaysDesc }

enum CrmListMode { browse, selecting }

/// 원장 모드 [고객] 탭 — CRM 대시보드 (초성검색·정렬·다중선택).
class DirectorCustomersTab extends StatefulWidget {
  const DirectorCustomersTab({super.key, required this.store});

  final SoriStore store;

  @override
  State<DirectorCustomersTab> createState() => _DirectorCustomersTabState();
}

class _DirectorCustomersTabState extends State<DirectorCustomersTab> {
  final _searchController = TextEditingController();
  String _query = '';
  _CustomerSort _sort = _CustomerSort.recentVisit;
  CrmListMode _mode = CrmListMode.browse;
  final Set<String> _selectedIds = {};
  bool _deleting = false;

  static const _dormantDays = 90;

  bool get _isSelecting => _mode == CrmListMode.selecting;

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

  void _enterSelecting({String? seedId}) {
    setState(() {
      _mode = CrmListMode.selecting;
      _selectedIds.clear();
      if (seedId != null && seedId.isNotEmpty) {
        _selectedIds.add(seedId);
      }
    });
  }

  void _exitSelecting() {
    setState(() {
      _mode = CrmListMode.browse;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (!_selectedIds.remove(id)) {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<Customer> list) {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(list.map((c) => c.id));
    });
  }

  Future<void> _bulkDelete() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty || _deleting) return;

    final store = widget.store;
    var chartCount = 0;
    var reviewCount = 0;
    for (final id in ids) {
      chartCount += store.charts.where((c) => c.customerId == id).length;
      reviewCount += store.reviews.where((r) => r.customerId == id).length;
    }
    String? primaryName;
    for (final c in store.customers) {
      if (ids.contains(c.id) && c.name.trim().isNotEmpty) {
        primaryName = c.name.trim();
        break;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RedZoneDeleteDialog(
        customerCount: ids.length,
        chartCount: chartCount,
        reviewCount: reviewCount,
        primaryName: primaryName,
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final result = await widget.store.bulkDeleteCustomers(ids);
      if (!mounted) return;
      _exitSelecting();
      final msg = result.hasFailures
          ? (result.deletedIds.isEmpty
              ? '삭제되지 않았습니다. 샵 소유권(로그인)을 확인해 주세요. (${result.failedIds.length}명)'
              : '${result.deletedIds.length}명 삭제 · ${result.failedIds.length}명은 권한 없음 또는 실패')
          : '${result.deletedIds.length}명 고객을 영구 삭제했습니다';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              result.hasFailures ? Colors.orangeAccent : SoriTokens.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('삭제 실패: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
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

  List<Customer> _sortedList() {
    final list = List<Customer>.of(widget.store.searchCustomers(_query));
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
      case _CustomerSort.dormantDaysDesc:
        list.sort((a, b) {
          final dormantCmp =
              (_isDormant(b) ? 1 : 0).compareTo(_isDormant(a) ? 1 : 0);
          if (dormantCmp != 0) return dormantCmp;
          return _daysSinceVisit(b).compareTo(_daysSinceVisit(a));
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

  Future<void> _requestReview(Customer c) async {
    await requestCustomerReviewWithQr(
      context,
      store: widget.store,
      customer: c,
    );
  }

  void _pickSort() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SoriTokens.surface,
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
                  _CustomerSort.dormantDaysDesc => '장기 미방문순',
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
    final list = _sortedList();
    final bottomPad = 100 + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              if (!_isSelecting)
                SliverAppBar(
                  pinned: false,
                  floating: true,
                  snap: true,
                  expandedHeight: 248,
                  collapsedHeight: 0,
                  toolbarHeight: 0,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  forceElevated: false,
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: Align(
                      alignment: Alignment.topCenter,
                      child: TodayCareSchedulePanel(
                        store: widget.store,
                        slim: true,
                      ),
                    ),
                  ),
                ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _CrmStickyToolbarDelegate(
                  height: _isSelecting ? 56 : 118,
                  child: ColoredBox(
                    color: SoriTokens.background,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                          child: SizedBox(
                            height: 48,
                            child: Row(
                              children: [
                                if (_isSelecting) ...[
                                  Text(
                                    '${_selectedIds.length}명 선택',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: SoriTokens.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: list.isEmpty
                                        ? null
                                        : () => _selectAll(list),
                                    child: const Text('전체'),
                                  ),
                                  TextButton(
                                    onPressed:
                                        _deleting ? null : _exitSelecting,
                                    child: const Text('취소'),
                                  ),
                                  FilledButton(
                                    onPressed: _deleting ||
                                            _selectedIds.isEmpty
                                        ? null
                                        : _bulkDelete,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                    ),
                                    child: Text(
                                      _deleting ? '삭제 중…' : '삭제',
                                    ),
                                  ),
                                ] else ...[
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
                                  const Spacer(),
                                  IconButton(
                                    tooltip: '편집',
                                    onPressed: isEmptyDb
                                        ? null
                                        : () => _enterSelecting(),
                                    icon: const Icon(
                                      Icons.checklist_rtl_rounded,
                                    ),
                                    color: SoriTokens.primary,
                                  ),
                                  IconButton(
                                    tooltip: '정렬',
                                    onPressed:
                                        isEmptyDb ? null : _pickSort,
                                    icon: const Icon(
                                      Icons.filter_list_rounded,
                                    ),
                                    color: SoriTokens.primary,
                                  ),
                                  IconButton(
                                    tooltip: '고객 추가',
                                    onPressed: _addCustomer,
                                    icon: const Icon(
                                      Icons.person_add_alt_1_rounded,
                                    ),
                                    color: SoriTokens.primary,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (!_isSelecting)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (v) =>
                                  setState(() => _query = v),
                              enabled: !isEmptyDb,
                              style: const TextStyle(
                                color: SoriTokens.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: '이름 · 초성(ㅎㄱㄷ) · 전화번호',
                                hintStyle: const TextStyle(
                                  color: SoriTokens.textSecondary,
                                ),
                                isDense: true,
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: SoriTokens.textSecondary,
                                ),
                                filled: true,
                                fillColor: SoriTokens.surface,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: SoriTokens.outlinePurple,
                                    width: 1.2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: SoriTokens.outlinePurple,
                                    width: 1.2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: SoriTokens.primary,
                                    width: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
          body: isEmptyDb
              ? _EmptyCustomersState(onAdd: _addCustomer)
              : _CustomerListBody(
                  list: list,
                  emptyLabel: '검색 결과가 없습니다',
                  formatDate: _formatDate,
                  lastVisitOf: _lastVisitOf,
                  daysSince: _daysSinceVisit,
                  bottomPadding: bottomPad,
                  showDormantHint:
                      _sort == _CustomerSort.dormantDaysDesc &&
                          !_isSelecting,
                  selecting: _isSelecting,
                  selectedIds: _selectedIds,
                  onAdd: _addCustomer,
                  onOpen: _openDetail,
                  onRequestReview: _requestReview,
                  onToggleSelect: _toggleSelected,
                  onLongPress: (c) {
                    if (_isSelecting) {
                      _toggleSelected(c.id);
                    } else {
                      _enterSelecting(seedId: c.id);
                    }
                  },
                ),
        ),
      ),
    );
  }
}

/// Red Zone — 체크 필수 후 영구 삭제 활성화.
class _RedZoneDeleteDialog extends StatefulWidget {
  const _RedZoneDeleteDialog({
    required this.customerCount,
    required this.chartCount,
    required this.reviewCount,
    this.primaryName,
  });

  final int customerCount;
  final int chartCount;
  final int reviewCount;
  final String? primaryName;

  @override
  State<_RedZoneDeleteDialog> createState() => _RedZoneDeleteDialogState();
}

class _RedZoneDeleteDialogState extends State<_RedZoneDeleteDialog> {
  bool _acked = false;

  @override
  Widget build(BuildContext context) {
    final who = widget.customerCount == 1 &&
            (widget.primaryName?.isNotEmpty ?? false)
        ? '"${widget.primaryName}"'
        : (widget.primaryName == null || widget.primaryName!.isEmpty
            ? '${widget.customerCount}명'
            : '"${widget.primaryName}" 외 ${widget.customerCount - 1}명');

    return AlertDialog(
      backgroundColor: SoriTokens.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        '⚠ 고객 ${widget.customerCount}명을 영구 삭제할까요?',
        style: const TextStyle(
          color: Color(0xFFF87171),
          fontWeight: FontWeight.w900,
          fontSize: 17,
          height: 1.3,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$who 고객 데이터가 영구 삭제됩니다.',
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: SoriTokens.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '삭제되면 함께 사라집니다',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '· 시술 차트  ${widget.chartCount}건\n'
            '· 소통 리뷰  ${widget.reviewCount}건\n'
            '· 회원권·티켓 데이터',
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: SoriTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => setState(() => _acked = !_acked),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _acked,
                    onChanged: (v) => setState(() => _acked = v ?? false),
                    activeColor: const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '위 내용을 이해했으며 복구할 수 없음을 확인합니다',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _acked ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            disabledBackgroundColor: const Color(0xFF3F3F46),
          ),
          child: const Text('영구 삭제'),
        ),
      ],
    );
  }
}

class _CrmStickyToolbarDelegate extends SliverPersistentHeaderDelegate {
  _CrmStickyToolbarDelegate({
    required this.height,
    required this.child,
  });

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(height: height, child: child);
  }

  @override
  bool shouldRebuild(covariant _CrmStickyToolbarDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
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
    required this.selecting,
    required this.selectedIds,
    required this.onAdd,
    required this.onOpen,
    required this.onRequestReview,
    required this.onToggleSelect,
    required this.onLongPress,
    this.bottomPadding = 100,
  });

  final List<Customer> list;
  final String emptyLabel;
  final String Function(DateTime) formatDate;
  final DateTime Function(Customer) lastVisitOf;
  final int Function(Customer) daysSince;
  final bool showDormantHint;
  final bool selecting;
  final Set<String> selectedIds;
  final VoidCallback onAdd;
  final ValueChanged<Customer> onOpen;
  final ValueChanged<Customer> onRequestReview;
  final ValueChanged<String> onToggleSelect;
  final ValueChanged<Customer> onLongPress;
  final double bottomPadding;

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
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
      itemCount: list.length + (showDormantHint ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (showDormantHint && index == 0) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SoriTokens.warningBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: SoriTokens.warningText.withValues(alpha: 0.45),
              ),
            ),
            child: const Text(
              '90일 이상 미방문 고객이 위에 모여 있습니다. 케어 리마인드·티켓팅 제안 타이밍을 확인해 주세요.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: SoriTokens.warningText,
              ),
            ),
          );
        }
        final c = list[showDormantHint ? index - 1 : index];
        final remain = c.membershipRemainingVisits;
        final hasMembership = c.isMembershipCustomer;
        final ticketingUrgent = hasMembership && remain >= 1 && remain <= 2;
        final selected = selectedIds.contains(c.id);
        return _DenseCustomerTile(
          name: c.name,
          phone: c.phone,
          lastVisitLabel: formatDate(lastVisitOf(c)),
          dormantDays: daysSince(c),
          remainLabel: hasMembership ? '잔여 $remain회' : '회원권 미등록',
          remainUrgent: ticketingUrgent,
          remainWarn: hasMembership && c.isMembershipLow && !ticketingUrgent,
          selecting: selecting,
          selected: selected,
          onTap: () {
            if (selecting) {
              onToggleSelect(c.id);
            } else {
              onOpen(c);
            }
          },
          onLongPress: () => onLongPress(c),
          onRequestReview: selecting ? null : () => onRequestReview(c),
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
    required this.onLongPress,
    this.onRequestReview,
    this.dormantDays = 0,
    this.remainUrgent = false,
    this.remainWarn = false,
    this.selecting = false,
    this.selected = false,
  });

  final String name;
  final String phone;
  final String lastVisitLabel;
  final int dormantDays;
  final String remainLabel;
  final bool remainUrgent;
  final bool remainWarn;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onRequestReview;

  @override
  Widget build(BuildContext context) {
    final badgeBg = remainUrgent
        ? const Color(0xFF2A1518)
        : (remainWarn ? SoriTokens.warningBg : SoriTokens.primarySoft);
    final badgeFg = remainUrgent
        ? const Color(0xFFEF9A9A)
        : (remainWarn ? SoriTokens.warningText : SoriTokens.primary);

    return SoriCard(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        children: [
          if (selecting) ...[
            Checkbox(
              value: selected,
              onChanged: (_) => onTap(),
              activeColor: SoriTokens.primary,
            ),
            const SizedBox(width: 4),
          ],
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
          if (!selecting)
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
                        ? Border.all(color: const Color(0xFF7F1D1D))
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
                const SizedBox(height: 6),
                TextButton(
                  onPressed: onRequestReview,
                  style: TextButton.styleFrom(
                    foregroundColor: SoriTokens.primary,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '후기 요청',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
