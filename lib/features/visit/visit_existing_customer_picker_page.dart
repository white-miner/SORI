import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';

/// Flow B — 기존 고객 검색·선택 (풀스크린, 모달 아님).
class VisitExistingCustomerPickerPage extends StatefulWidget {
  const VisitExistingCustomerPickerPage({super.key, required this.store});

  final SoriStore store;

  @override
  State<VisitExistingCustomerPickerPage> createState() =>
      _VisitExistingCustomerPickerPageState();
}

class _VisitExistingCustomerPickerPageState
    extends State<VisitExistingCustomerPickerPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _chartCount(String customerId) =>
      widget.store.chartsForCustomer(customerId).length;

  List<Customer> get _filtered {
    final q = _query.trim().toLowerCase();
    final all = widget.store.customers;
    if (q.isEmpty) {
      return List<Customer>.from(all)
        ..sort((a, b) => b.lastTreatmentDate.compareTo(a.lastTreatmentDate));
    }
    return all
        .where((c) {
          final name = c.name.toLowerCase();
          final phone = c.phone.replaceAll(RegExp(r'\D'), '');
          final qq = q.replaceAll(RegExp(r'\D'), '');
          return name.contains(q) ||
              (qq.isNotEmpty && phone.contains(qq));
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: const Text('기존 고객 선택'),
        backgroundColor: SoriTokens.surface,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '이름 또는 연락처 검색',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: SoriTokens.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: SoriTokens.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: SoriTokens.border),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '선택 즉시 직전 회차 요약과 과거 B/A가 상단에 고정됩니다.',
              style: TextStyle(
                fontSize: 13,
                color: SoriTokens.textSecondary.withValues(alpha: 0.95),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      '고객을 찾을 수 없어요.',
                      style: TextStyle(color: SoriTokens.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final c = items[i];
                      final visits = _chartCount(c.id);
                      return Material(
                        color: SoriTokens.surface,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.pop(context, c),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: SoriTokens.border),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: SoriTokens.surface,
                                  child: Text(
                                    c.name.characters.first,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        c.phone,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: SoriTokens.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (visits > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: SoriTokens.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: SoriTokens.border,
                                      ),
                                    ),
                                    child: Text(
                                      '${visits}회차',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
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
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
