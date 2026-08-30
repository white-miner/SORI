import 'package:flutter/material.dart';

import '../../crm_kernel/theme/crm_calm_glass_tokens.dart';
import '../../models/customer.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../widgets/crm/crm_calm_glass_widgets.dart';

/// 원장 수동 일정 추가 — Phase CRM-1.
Future<bool?> showAddManualScheduleSheet(
  BuildContext context, {
  required SoriStore store,
  required DateTime initialDay,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddManualScheduleSheet(
      store: store,
      initialDay: initialDay,
    ),
  );
}

class _AddManualScheduleSheet extends StatefulWidget {
  const _AddManualScheduleSheet({
    required this.store,
    required this.initialDay,
  });

  final SoriStore store;
  final DateTime initialDay;

  @override
  State<_AddManualScheduleSheet> createState() =>
      _AddManualScheduleSheetState();
}

class _AddManualScheduleSheetState extends State<_AddManualScheduleSheet> {
  final _careCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  Customer? _customer;
  late TimeOfDay _time;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _time = TimeOfDay.fromDateTime(
      DateTime.now().add(const Duration(hours: 1)),
    );
  }

  @override
  void dispose() {
    _careCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCustomer() async {
    final customers = widget.store.customers;
    if (customers.isEmpty) return;
    final picked = await showModalBottomSheet<Customer>(
      context: context,
      backgroundColor: SoriTokens.surface,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '고객 선택',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            for (final c in customers)
              ListTile(
                title: Text(c.name),
                subtitle: Text(c.phone),
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _customer = picked);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (t != null) setState(() => _time = t);
  }

  Future<void> _save() async {
    final name = _customer?.name.trim() ?? '';
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('고객을 선택해 주세요.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final scheduledAt = DateTime(
        widget.initialDay.year,
        widget.initialDay.month,
        widget.initialDay.day,
        _time.hour,
        _time.minute,
      );
      await widget.store.crm.addManualSchedule(
        scheduledAt: scheduledAt,
        customerName: name,
        customerId: _customer?.id,
        customerPhone: _customer?.phone,
        careLabel: _careCtrl.text.trim(),
        note: _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: CrmCalmGlassCard(
        radius: CrmCalmGlassTokens.radiusXl,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
              '케어 일정 추가',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_customer?.name ?? '고객 선택'),
              subtitle: Text(_customer?.phone ?? '탭하여 고객을 고르세요'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _pickCustomer,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_time.format(context)),
              subtitle: const Text('시간'),
              trailing: const Icon(Icons.schedule_rounded),
              onTap: _pickTime,
            ),
            TextField(
              controller: _careCtrl,
              decoration: const InputDecoration(
                labelText: '케어 메뉴 (선택)',
                hintText: '예: 피부관리',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: CrmCalmGlassTokens.care,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(_saving ? '저장 중…' : '일정 저장'),
            ),
          ],
        ),
      ),
    );
  }
}
