import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'add_customer_sheet.dart';
import 'admin_chart_writer_page.dart';

/// FAB용 — 신규/기존 고객 차트 작성 분기 BottomSheet.
Future<void> showChartCustomerPickerSheet(
  BuildContext context, {
  required SoriStore store,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return _ChartCustomerPickerSheet(store: store);
    },
  );
}

class _ChartCustomerPickerSheet extends StatefulWidget {
  const _ChartCustomerPickerSheet({required this.store});

  final SoriStore store;

  @override
  State<_ChartCustomerPickerSheet> createState() =>
      _ChartCustomerPickerSheetState();
}

class _ChartCustomerPickerSheetState extends State<_ChartCustomerPickerSheet> {
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

  List<Customer> get _results => widget.store.searchCustomers(_query);

  Future<void> _openChart(Customer customer) async {
    Navigator.pop(context);
    if (!mounted) return;
    await openChartWriterForCustomer(
      context,
      store: widget.store,
      customer: customer,
      forceQuickChart: true,
    );
  }

  /// 신규 고객 기본 인적사항 입력 → 첫 차트 작성.
  Future<void> _openNewCustomerChart() async {
    Navigator.pop(context);
    if (!mounted) return;
    await showAddCustomerSheet(
      context,
      store: widget.store,
      title: '신규 고객 기본 정보',
      submitLabel: '등록하고 첫 차트 작성',
      openChartAfter: true,
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final results = _results;
    final hasQuery = _query.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '차트 작성',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '신규 등록 또는 기존 고객을 선택해 바로 작성하세요',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          // —— 신규 고객 CTA ——
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openNewCustomerChart,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF7B6CFF),
                      Color(0xFF5B4CDB),
                      Color(0xFF4A3BCF),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: SoriTokens.primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_circle_rounded, color: Colors.white, size: 26),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '➕ 신규 고객 차트 작성',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
          Row(
            children: [
              Icon(
                Icons.bolt_rounded,
                size: 18,
                color: Colors.amber.shade700,
              ),
              const SizedBox(width: 4),
              const Text(
                '기존 고객 간편 차트 검색/선택',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '총 ${widget.store.customers.length}명 · 선택 시 1초 간편 차트로 이동',
            style: const TextStyle(
              fontSize: 12,
              color: SoriTokens.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: '이름 · 전화번호 검색',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: SoriTokens.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.38,
            ),
            child: results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      hasQuery
                          ? '검색 결과가 없어요 · 위에서 신규 고객으로 작성해 보세요'
                          : '등록된 고객이 없습니다 · 위 버튼으로 첫 차트를 시작하세요',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: SoriTokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final c = results[index];
                      final remain = c.isMembershipCustomer
                          ? '잔여 ${c.membershipRemainingVisits}회'
                          : '회원권 미등록';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: SoriTokens.primarySoft,
                          child: Text(
                            c.name.characters.first,
                            style: const TextStyle(
                              color: SoriTokens.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${c.phone} · ${_formatDate(c.lastTreatmentDate)} · $remain',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.edit_note_rounded),
                        onTap: () => _openChart(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
