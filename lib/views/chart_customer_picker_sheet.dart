import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'add_customer_sheet.dart';
import 'admin_chart_writer_page.dart';

/// FAB용 — 차트 작성할 고객 검색/선택/신규 등록 BottomSheet.
Future<void> showChartCustomerPickerSheet(
  BuildContext context, {
  required SoriStore store,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
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
    );
  }

  Future<void> _registerAndWrite() async {
    final digits = SoriStore.normalizePhone(_query);
    final looksLikePhone = digits.length >= 4;
    final looksLikeName =
        _query.trim().isNotEmpty && !RegExp(r'^\d').hasMatch(_query.trim());

    final created = await showAddCustomerSheet(
      context,
      store: widget.store,
      initialName: looksLikeName ? _query.trim() : null,
      initialPhone: looksLikePhone ? _query.trim() : null,
      title: '신규 고객 등록 후 차트 작성',
      submitLabel: '등록하고 차트 쓰기',
    );
    if (created == null || !mounted) return;
    Navigator.pop(context);
    if (!mounted) return;
    await openChartWriterForCustomer(
      context,
      store: widget.store,
      customer: created,
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final results = _results;
    final hasQuery = _query.trim().isNotEmpty;
    final showCreateCta = results.isEmpty;

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
          const SizedBox(height: 14),
          const Text(
            '차트 작성할 고객 선택',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '총 ${widget.store.customers.length}명 · 이름 또는 번호로 검색하세요',
            style: const TextStyle(
              fontSize: 13,
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            autofocus: true,
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
              maxHeight: MediaQuery.sizeOf(context).height * 0.42,
            ),
            child: results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      hasQuery
                          ? '검색 결과가 없어요'
                          : '등록된 고객이 없습니다. 아래에서 바로 등록하세요.',
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
          if (showCreateCta) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _registerAndWrite,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text(
                '+ 신규 고객 등록하고 차트 쓰기',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: SoriTokens.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
