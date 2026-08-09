import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/sori_card.dart';
import 'add_customer_sheet.dart';
import 'admin_chart_page.dart';

/// 원장 모드 [고객] 탭 — 검색·목록·단독 등록.
class DirectorCustomersTab extends StatefulWidget {
  const DirectorCustomersTab({super.key, required this.store});

  final SoriStore store;

  @override
  State<DirectorCustomersTab> createState() => _DirectorCustomersTabState();
}

class _DirectorCustomersTabState extends State<DirectorCustomersTab> {
  final _searchController = TextEditingController();
  String _query = '';

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

  List<Customer> get _filtered => widget.store.searchCustomers(_query);

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  DateTime _lastVisitOf(Customer c) {
    final chart = widget.store.latestChart(c.id);
    return chart?.visitCheckedAt ??
        chart?.feedbackLineOpenedAt ??
        c.lastTreatmentDate;
  }

  Future<void> _addCustomer() async {
    await showAddCustomerSheet(context, store: widget.store);
  }

  void _openDetail(Customer c) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminChartPage(
          store: widget.store,
          customerId: c.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.store.customers;
    final list = _filtered;
    final isEmptyDb = all.isEmpty;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '고객',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.textPrimary,
                    ),
                  ),
                ),
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
                hintText: '이름 · 전화번호 검색',
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
            child: isEmptyDb
                ? _EmptyCustomersState(onAdd: _addCustomer)
                : list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '검색 결과가 없습니다',
                              style: TextStyle(
                                color: SoriTokens.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _addCustomer,
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: const Text('새 고객 등록'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final c = list[index];
                          return _DenseCustomerTile(
                            name: c.name,
                            phone: c.phone,
                            lastVisitLabel: _formatDate(_lastVisitOf(c)),
                            remainLabel: c.isMembershipCustomer
                                ? '잔여 ${c.membershipRemainingVisits}회'
                                : '회원권 미등록',
                            remainWarn: c.isMembershipLow,
                            onTap: () => _openDetail(c),
                          );
                        },
                      ),
          ),
        ],
      ),
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
    this.remainWarn = false,
  });

  final String name;
  final String phone;
  final String lastVisitLabel;
  final String remainLabel;
  final bool remainWarn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                    Text(
                      '최근 $lastVisitLabel',
                      style: const TextStyle(
                        fontSize: 12,
                        color: SoriTokens.textSecondary,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: remainWarn
                      ? SoriTokens.warningBg
                      : SoriTokens.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  remainLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: remainWarn
                        ? SoriTokens.warningText
                        : SoriTokens.primary,
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
