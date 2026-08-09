import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

/// 고객 단독 등록 바텀시트. 성공 시 저장된 [Customer]를 반환한다.
Future<Customer?> showAddCustomerSheet(
  BuildContext context, {
  required SoriStore store,
  String? initialName,
  String? initialPhone,
  String title = '신규 고객 등록',
  String submitLabel = '고객 등록',
}) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return _AddCustomerSheet(
        store: store,
        initialName: initialName,
        initialPhone: initialPhone,
        title: title,
        submitLabel: submitLabel,
      );
    },
  );
}

class _AddCustomerSheet extends StatefulWidget {
  const _AddCustomerSheet({
    required this.store,
    required this.title,
    required this.submitLabel,
    this.initialName,
    this.initialPhone,
  });

  final SoriStore store;
  final String? initialName;
  final String? initialPhone;
  final String title;
  final String submitLabel;

  @override
  State<_AddCustomerSheet> createState() => _AddCustomerSheetState();
}

class _AddCustomerSheetState extends State<_AddCustomerSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _memoController;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
    _memoController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('고객 성함을 입력해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (SoriStore.normalizePhone(phone).length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('전화번호를 올바르게 입력해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final existing = widget.store.findCustomerByPhone(phone);
    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이미 등록된 번호예요 · ${existing.name}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: SoriTokens.warningText,
        ),
      );
      Navigator.pop(context, existing);
      return;
    }

    setState(() => _saving = true);
    try {
      final saved = await widget.store.addCustomerAsync(
        Customer(
          id: 'c-${DateTime.now().millisecondsSinceEpoch}',
          shopId: widget.store.shop.id,
          name: name,
          phone: phone,
          lastTreatmentDate: DateTime.now(),
          treatmentType: '',
          memo: _memoController.text.trim(),
          membershipTotalVisits: 0,
        ),
      );
      if (!mounted) return;
      widget.store.clearError();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${saved.name}님을 등록했어요'),
          backgroundColor: SoriTokens.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '등록 실패: ${widget.store.lastError ?? e.toString()}',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
      widget.store.clearError();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
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
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '차트 작성과 별도로 고객만 먼저 등록할 수 있어요',
            style: TextStyle(
              fontSize: 13,
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '고객명',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '전화번호',
              hintText: '010-0000-0000',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _memoController,
            decoration: const InputDecoration(
              labelText: '메모 (선택)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.person_add_alt_1_rounded),
            label: Text(
              _saving ? '등록 중…' : widget.submitLabel,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: SoriTokens.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
