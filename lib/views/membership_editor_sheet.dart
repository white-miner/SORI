import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/customer.dart';
import '../models/customer_membership.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'management_menu_field.dart';
import 'my_app.dart';

/// 회원권 등록/관리 바텀 시트. 저장 시 고객 memberships를 즉시 upsert.
Future<List<CustomerMembership>?> showMembershipEditorSheet({
  required BuildContext context,
  required SoriStore store,
  required Customer customer,
  List<CustomerMembership>? initialMemberships,
  bool persistImmediately = true,
}) {
  return showModalBottomSheet<List<CustomerMembership>>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return _MembershipEditorSheet(
        store: store,
        customer: customer,
        initialMemberships:
            initialMemberships ?? List<CustomerMembership>.from(customer.memberships),
        persistImmediately: persistImmediately,
      );
    },
  );
}

class _MembershipEditorSheet extends StatefulWidget {
  const _MembershipEditorSheet({
    required this.store,
    required this.customer,
    required this.initialMemberships,
    required this.persistImmediately,
  });

  final SoriStore store;
  final Customer customer;
  final List<CustomerMembership> initialMemberships;
  final bool persistImmediately;

  @override
  State<_MembershipEditorSheet> createState() => _MembershipEditorSheetState();
}

class _MembershipEditorSheetState extends State<_MembershipEditorSheet> {
  late List<CustomerMembership> _memberships;
  bool _saving = false;

  List<String> get _serviceOptions => widget.store.shop.serviceNames;

  @override
  void initState() {
    super.initState();
    _memberships = List<CustomerMembership>.from(widget.initialMemberships);
  }

  void _addMembership() {
    setState(() {
      _memberships = [
        ..._memberships,
        CustomerMembership(
          id: 'm-${DateTime.now().millisecondsSinceEpoch}',
          serviceName: _serviceOptions.isNotEmpty ? _serviceOptions.first : '',
          totalVisits: 10,
          usedVisits: 0,
        ),
      ];
    });
  }

  void _removeMembership(String id) {
    setState(() {
      _memberships = _memberships.where((m) => m.id != id).toList();
    });
  }

  void _updateMembership(int index, CustomerMembership next) {
    setState(() {
      final list = List<CustomerMembership>.from(_memberships);
      list[index] = next;
      _memberships = list;
    });
  }

  Future<void> _save() async {
    final cleaned = _memberships
        .where((m) => m.serviceName.trim().isNotEmpty && m.totalVisits > 0)
        .toList();

    if (!widget.persistImmediately) {
      Navigator.pop(context, cleaned);
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.store.saveCustomerMemberships(
        customerId: widget.customer.id,
        memberships: cleaned,
      );
      if (!mounted) return;
      if (widget.store.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: ${widget.store.lastError}'),
            backgroundColor: SoriTokens.systemRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.store.clearError();
        return;
      }
      Navigator.pop(context, cleaned);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 실패: $e'),
          backgroundColor: SoriTokens.systemRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '회원권 등록 / 관리',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        child: const Text('닫기'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '${widget.customer.name} · 방문 확인 시 오늘 관리 메뉴와 같은 회원권만 1회 차감됩니다.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    children: [
                      if (_memberships.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            '등록된 회원권이 없습니다. 아래에서 추가해 주세요.',
                            style: TextStyle(
                              fontSize: 13,
                              color: SoriTokens.textSecondary,
                            ),
                          ),
                        ),
                      ...List.generate(_memberships.length, (index) {
                        final m = _memberships[index];
                        final remain = m.remainingVisits;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border.all(color: SoriTokens.border),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '회원권 ${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '삭제',
                                    onPressed: () => _removeMembership(m.id),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                              ManagementMenuField(
                                label: '관리 메뉴',
                                value: m.serviceName,
                                options: _serviceOptions,
                                onChanged: (v) => _updateMembership(
                                  index,
                                  m.copyWith(serviceName: v),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _VisitSpinner(
                                label: '총 횟수',
                                value: m.totalVisits,
                                onMinus: () => _updateMembership(
                                  index,
                                  m.copyWith(
                                    totalVisits:
                                        (m.totalVisits - 1).clamp(0, 99),
                                    usedVisits: m.usedVisits.clamp(
                                      0,
                                      (m.totalVisits - 1).clamp(0, 99),
                                    ),
                                  ),
                                ),
                                onPlus: () => _updateMembership(
                                  index,
                                  m.copyWith(
                                    totalVisits:
                                        (m.totalVisits + 1).clamp(0, 99),
                                  ),
                                ),
                                onChanged: (v) => _updateMembership(
                                  index,
                                  m.copyWith(
                                    totalVisits: v.clamp(0, 99),
                                    usedVisits:
                                        m.usedVisits.clamp(0, v.clamp(0, 99)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _VisitSpinner(
                                label: '사용 횟수',
                                value: m.usedVisits,
                                onMinus: () => _updateMembership(
                                  index,
                                  m.copyWith(
                                    usedVisits: (m.usedVisits - 1)
                                        .clamp(0, m.totalVisits),
                                  ),
                                ),
                                onPlus: () => _updateMembership(
                                  index,
                                  m.copyWith(
                                    usedVisits: (m.usedVisits + 1)
                                        .clamp(0, m.totalVisits),
                                  ),
                                ),
                                onChanged: (v) => _updateMembership(
                                  index,
                                  m.copyWith(
                                    usedVisits: v.clamp(0, m.totalVisits),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '잔여 $remain회',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: remain <= 2 && m.totalVisits > 0
                                      ? SoriTokens.textSecondary
                                      : MyApp.soriPurple,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _addMembership,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: SoriTokens.primary,
                            side: const BorderSide(color: SoriTokens.primary),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            '+ 회원권 추가',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: MyApp.soriPurple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _saving ? '저장 중…' : '회원권 저장',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VisitSpinner extends StatelessWidget {
  const _VisitSpinner({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.onChanged,
  });

  final String label;
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        IconButton.filledTonal(
          onPressed: onMinus,
          icon: const Icon(Icons.remove, size: 18),
          style: IconButton.styleFrom(
            backgroundColor: MyApp.soriPurple.withValues(alpha: 0.12),
            foregroundColor: MyApp.soriPurple,
          ),
        ),
        SizedBox(
          width: 56,
          child: TextField(
            key: ValueKey('$label-$value'),
            controller: TextEditingController(text: '$value'),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(),
            ),
            onChanged: (raw) {
              final parsed = int.tryParse(raw.trim());
              if (parsed != null) onChanged(parsed);
            },
          ),
        ),
        IconButton.filledTonal(
          onPressed: onPlus,
          icon: const Icon(Icons.add, size: 18),
          style: IconButton.styleFrom(
            backgroundColor: MyApp.soriPurple.withValues(alpha: 0.12),
            foregroundColor: MyApp.soriPurple,
          ),
        ),
      ],
    );
  }
}
