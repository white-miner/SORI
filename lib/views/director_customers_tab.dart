import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/customer.dart';
import '../services/customer_crm_status_resolver.dart';
import '../services/sori_store.dart';
import '../routing/sori_router.dart';
import '../theme/sori_tokens.dart';
import '../widgets/sori_card.dart';
import '../widgets/sori_crm_status_avatar.dart';
import '../widgets/today_care_schedule_panel.dart';
import 'add_customer_sheet.dart';
import 'customer_merge_wizard.dart';
import 'request_customer_review.dart';

enum _CustomerSort { recentVisit, nameAsc, chartNo, dormantDaysDesc }

enum CrmListMode { browse, selectingDelete, selectingMerge }

/// 고객 카드 차트 번호 라벨 (PO: 중복 이름·전화 구별용).
String chartLabelForCustomer(Customer c, SoriStore store) {
  final latest = store.latestChart(c.id);
  if (latest != null) {
    return 'Chart #${latest.displayChartNo}';
  }
  final charts = store.chartsForCustomer(c.id);
  if (charts.isEmpty) return 'Chart —';
  var maxNo = 0;
  for (final ch in charts) {
    final parsed = int.tryParse(ch.customChartNo?.trim() ?? '');
    final n = parsed ?? ch.visitNumber;
    if (n > maxNo) maxNo = n;
  }
  return maxNo > 0 ? 'Chart #$maxNo' : 'Chart —';
}

/// 고객 카드 잔여 회원권/티켓 뱃지 (데이터 없으면 '잔여 없음').
String remainBadgeLabelForCustomer(Customer c, SoriStore store) {
  if (c.isMembershipCustomer) {
    final remain = c.membershipRemainingVisits;
    return remain > 0 ? '잔여 $remain회' : '잔여 없음';
  }
  final ticketRemain = store.membershipTickets
      .where((t) => t.customerId == c.id && t.isActive)
      .fold<int>(0, (sum, t) => sum + t.remainingVisits);
  if (ticketRemain > 0) return '잔여 $ticketRemain회';
  return '잔여 없음';
}

/// 원장 모드 [고객] 탭 — CRM 대시보드 (초성검색·정렬·다중선택).
class DirectorCustomersTab extends StatefulWidget {
  const DirectorCustomersTab({super.key, required this.store});

  final SoriStore store;

  @override
  State<DirectorCustomersTab> createState() => _DirectorCustomersTabState();
}

class _DirectorCustomersTabState extends State<DirectorCustomersTab>
    with CrmRingScrollVisibility {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _query = '';
  _CustomerSort _sort = _CustomerSort.recentVisit;
  CrmListMode _mode = CrmListMode.browse;
  final Set<String> _selectedIds = {};
  bool _deleting = false;

  static const _dormantDays = 90;

  @override
  ScrollController get crmRingScrollController => _scrollController;

  bool get _isSelecting => _mode != CrmListMode.browse;
  bool get _isSelectingMerge => _mode == CrmListMode.selectingMerge;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
    _scrollController.addListener(_onScrollForRing);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.store.refreshCareScheduleEntries();
    });
  }

  void _onScrollForRing() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  void _enterSelectingDelete({String? seedId}) {
    setState(() {
      _mode = CrmListMode.selectingDelete;
      _selectedIds.clear();
      if (seedId != null && seedId.isNotEmpty) {
        _selectedIds.add(seedId);
      }
    });
  }

  void _enterSelectingMerge({String? seedId}) {
    setState(() {
      _mode = CrmListMode.selectingMerge;
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

  Future<void> _bulkMerge() async {
    final ids = _selectedIds.toList();
    if (ids.length < 2) return;
    final selected = widget.store.customers
        .where((c) => ids.contains(c.id))
        .toList();
    if (selected.length < 2) return;

    final ok = await showCustomerMergeWizard(
      context: context,
      store: widget.store,
      selected: selected,
    );
    if (ok && mounted) _exitSelecting();
  }

  Future<void> _bulkDelete() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty || _deleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: SoriTokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          '고객 삭제',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        content: Text(
          '선택한 ${ids.length}명의 고객 정보를 영구 삭제하시겠습니까? '
          '(잔여 회원권이 있는 경우 함께 소멸됩니다)',
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: SoriTokens.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: SoriTokens.systemRed,
            ),
            child: const Text('승인'),
          ),
        ],
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
          backgroundColor: SoriTokens.systemRed,
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
      useRootNavigator: true,
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

    return PrimaryScrollController(
      controller: _scrollController,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: TodayCareSchedulePanel(
                  store: widget.store,
                  slim: true,
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _CrmStickyToolbarDelegate(
                  height: 118,
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
                                    onPressed: _deleting ? null : _exitSelecting,
                                    child: const Text('취소'),
                                  ),
                                  if (_isSelectingMerge)
                                    FilledButton(
                                      onPressed: _selectedIds.length < 2
                                          ? null
                                          : _bulkMerge,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: SoriTokens.primary,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                      ),
                                      child: Text(
                                        '병합 (${_selectedIds.length})',
                                      ),
                                    )
                                  else
                                    FilledButton(
                                      onPressed: _deleting ||
                                              _selectedIds.isEmpty
                                          ? null
                                          : _bulkDelete,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: SoriTokens.primaryDark,
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
                                  TextButton(
                                    onPressed: isEmptyDb
                                        ? null
                                        : () => _enterSelectingDelete(),
                                    child: const Text(
                                      '선택',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '중복 병합',
                                    onPressed: isEmptyDb
                                        ? null
                                        : () => _enterSelectingMerge(),
                                    icon: const Icon(
                                      Icons.merge_type_rounded,
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
              if (isEmptyDb)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyCustomersState(onAdd: _addCustomer),
                )
              else
                ..._CustomerListSlivers.build(
                  list: list,
                  store: widget.store,
                  ringAnimateForIndex: crmRingAnimateForIndex,
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
                      _enterSelectingDelete(seedId: c.id);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
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

class _CustomerListSlivers {
  static List<Widget> build({
    required List<Customer> list,
    required SoriStore store,
    required bool Function(int index) ringAnimateForIndex,
    required String emptyLabel,
    required String Function(DateTime) formatDate,
    required DateTime Function(Customer) lastVisitOf,
    required int Function(Customer) daysSince,
    required bool showDormantHint,
    required bool selecting,
    required Set<String> selectedIds,
    required VoidCallback onAdd,
    required ValueChanged<Customer> onOpen,
    required ValueChanged<Customer> onRequestReview,
    required ValueChanged<String> onToggleSelect,
    required ValueChanged<Customer> onLongPress,
    double bottomPadding = 100,
  }) {
    if (list.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
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
          ),
        ),
      ];
    }

    final itemCount = list.length + (showDormantHint ? 1 : 0);
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
        sliver: SliverList.separated(
          itemCount: itemCount,
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
            final ticketRemain = store.membershipTickets
                .where((t) => t.customerId == c.id && t.isActive)
                .fold<int>(0, (sum, t) => sum + t.remainingVisits);
            final totalRemain =
                hasMembership ? remain : (ticketRemain > 0 ? ticketRemain : 0);
            final ticketingUrgent =
                totalRemain >= 1 && totalRemain <= 2;
            final selected = selectedIds.contains(c.id);
            final listIndex = showDormantHint ? index - 1 : index;
            final ringVisual = CustomerCrmStatusResolver.resolve(
              c,
              store.charts,
            );
            return _DenseCustomerTile(
              name: c.name,
              phone: c.phone,
              chartLabel: chartLabelForCustomer(c, store),
              ringVisual: ringVisual,
              animateRing: ringAnimateForIndex(listIndex),
              lastVisitLabel: formatDate(lastVisitOf(c)),
              dormantDays: daysSince(c),
              remainLabel: remainBadgeLabelForCustomer(c, store),
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
        ),
      ),
    ];
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
    required this.chartLabel,
    required this.ringVisual,
    required this.animateRing,
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
  final String chartLabel;
  final CrmRingVisual ringVisual;
  final bool animateRing;
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
    final badgeBg = remainUrgent || remainWarn
        ? SoriTokens.systemRed
        : SoriTokens.chipIdleBg;
    final badgeFg = remainUrgent || remainWarn
        ? Colors.white
        : SoriTokens.tabUnselected;

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
          SoriCrmStatusAvatar(
            name: name,
            visual: ringVisual,
            radius: 20,
            animateWhenVisible: animateRing,
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
                const SizedBox(height: 2),
                Text(
                  chartLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: SoriTokens.primary,
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
              if (!selecting) ...[
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
            ],
          ),
        ],
      ),
    );
  }
}
