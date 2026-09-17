import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';

/// Flow A — 신규 고객 기본 정보 입력 (풀스크린, 모달 아님).
class VisitNewCustomerFormPage extends StatefulWidget {
  const VisitNewCustomerFormPage({
    super.key,
    required this.store,
    this.initialName,
  });

  final SoriStore store;
  final String? initialName;

  @override
  State<VisitNewCustomerFormPage> createState() =>
      _VisitNewCustomerFormPageState();
}

class _VisitNewCustomerFormPageState extends State<VisitNewCustomerFormPage> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final prefill = widget.initialName?.trim() ?? '';
    if (prefill.isNotEmpty) {
      _nameCtrl.text = prefill;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty) {
      _snack('고객 성함을 입력해 주세요.');
      return;
    }
    if (SoriStore.normalizePhone(phone).length < 10) {
      _snack('전화번호를 올바르게 입력해 주세요.');
      return;
    }

    final existing = widget.store.findCustomerByPhone(phone);
    if (existing != null) {
      _snack('이미 등록된 번호입니다. 「기존 고객 상담」을 이용해 주세요.');
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
          memo: _memoCtrl.text.trim(),
          membershipTotalVisits: 0,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) _snack('등록 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: const Text('신규 고객 등록'),
        backgroundColor: SoriTokens.surface,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Text(
            '첫 방문 고객님의 기본 정보를 입력한 뒤\n바로 1회차 상담 시트로 이동합니다.',
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: SoriTokens.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '성함',
              hintText: '예: 홍길동',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '연락처',
              hintText: '010-0000-0000',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _memoCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '메모 (선택)',
              hintText: '유입 경로, 특이사항 등',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: SoriTokens.primary,
              minimumSize: const Size.fromHeight(50),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    '신규 상담 시트 시작',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
        ],
      ),
    );
  }
}
