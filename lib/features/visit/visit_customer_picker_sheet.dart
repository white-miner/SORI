import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../visit_kernel/theme/visit_glass_tokens.dart';

Future<Customer?> showVisitCustomerPickerSheet(
  BuildContext context, {
  required SoriStore store,
}) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => _VisitCustomerPickerBody(store: store),
  );
}

class _VisitCustomerPickerBody extends StatefulWidget {
  const _VisitCustomerPickerBody({required this.store});

  final SoriStore store;

  @override
  State<_VisitCustomerPickerBody> createState() =>
      _VisitCustomerPickerBodyState();
}

class _VisitCustomerPickerBodyState extends State<_VisitCustomerPickerBody> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final items = _filtered.take(50).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SoriTokens.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '오늘 방문하시는 고객님',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: '이름 또는 연락처 검색',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: VisitGlassTokens.care.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.45,
            ),
            child: items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '고객을 찾을 수 없어요.',
                      textAlign: TextAlign.center,
                      style: VisitGlassTokens.bodyCalm.copyWith(
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final c = items[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(c.name),
                        subtitle: Text(
                          c.phone,
                          style: VisitGlassTokens.captionCalm.copyWith(
                            color: SoriTokens.textSecondary,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded,
                            size: 16),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
