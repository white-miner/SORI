import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../visit_kernel/theme/visit_glass_tokens.dart';

Future<Customer?> showVisitCustomerPickerSheet(
  BuildContext context, {
  required SoriStore store,
  bool allowQuickCreate = false,
}) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => _VisitCustomerPickerBody(
      store: store,
      allowQuickCreate: allowQuickCreate,
    ),
  );
}

class _VisitCustomerPickerBody extends StatefulWidget {
  const _VisitCustomerPickerBody({
    required this.store,
    this.allowQuickCreate = false,
  });

  final SoriStore store;
  final bool allowQuickCreate;

  @override
  State<_VisitCustomerPickerBody> createState() =>
      _VisitCustomerPickerBodyState();
}

class _VisitCustomerPickerBodyState extends State<_VisitCustomerPickerBody> {
  final _search = TextEditingController();
  final _quickName = TextEditingController();
  final _quickPhone = TextEditingController();
  String _query = '';
  var _showQuickForm = false;
  var _saving = false;

  @override
  void dispose() {
    _search.dispose();
    _quickName.dispose();
    _quickPhone.dispose();
    super.dispose();
  }

  bool get _queryLooksLikePhone {
    final digits = _query.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 4 && digits.length >= _query.trim().length - 2;
  }

  List<Customer> get _filtered {
    final q = _query.trim().toLowerCase();
    final all = widget.store.customers;
    if (q.isEmpty) {
      return List<Customer>.from(all)
        ..sort((a, b) => b.lastTreatmentDate.compareTo(a.lastTreatmentDate));
    }
    return all.where((c) {
      final name = c.name.toLowerCase();
      final phone = c.phone.replaceAll(RegExp(r'\D'), '');
      final qq = q.replaceAll(RegExp(r'\D'), '');
      return name.contains(q) || (qq.isNotEmpty && phone.contains(qq));
    }).toList();
  }

  void _openQuickForm() {
    final q = _query.trim();
    if (_queryLooksLikePhone) {
      _quickPhone.text = q;
      if (_quickName.text.trim().isEmpty) _quickName.clear();
    } else {
      _quickName.text = q;
    }
    setState(() => _showQuickForm = true);
  }

  Future<void> _saveQuick() async {
    final name = _quickName.text.trim();
    final phone = _quickPhone.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.store.addCustomerAsync(
        Customer(
          id: '',
          shopId: widget.store.shop.id,
          name: name,
          phone: phone,
          lastTreatmentDate: DateTime.now(),
          treatmentType: '',
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final items = _filtered.take(50).toList();
    final showCta = widget.allowQuickCreate &&
        _query.trim().isNotEmpty &&
        !_showQuickForm;

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
            onChanged: (v) => setState(() {
              _query = v;
              _showQuickForm = false;
            }),
          ),
          if (showCta) ...[
            const SizedBox(height: 8),
            TextButton(
              key: const Key('program-quick-create'),
              onPressed: _openQuickForm,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF8B5CF6),
                alignment: Alignment.centerLeft,
              ),
              child: Text(
                "'${_query.trim()}' 신규 등록",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          if (_showQuickForm) ...[
            const SizedBox(height: 8),
            TextField(
              key: const Key('program-quick-create-name'),
              controller: _quickName,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('program-quick-create-phone'),
              controller: _quickPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '연락처'),
            ),
            const SizedBox(height: 10),
            FilledButton(
              key: const Key('program-quick-create-save'),
              onPressed: _saving ? null : _saveQuick,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1C1C1E),
                foregroundColor: Colors.white,
              ),
              child: Text(_saving ? '등록 중…' : '등록하고 이어서'),
            ),
          ],
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.45,
            ),
            child: items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      widget.allowQuickCreate
                          ? '검색 결과가 없어요. 위에서 신규로 등록할 수 있습니다.'
                          : '고객을 찾을 수 없어요.',
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
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                        ),
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
