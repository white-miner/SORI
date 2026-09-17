import 'package:flutter/material.dart';

import '../../../models/customer.dart';
import '../../../models/program_sales.dart';
import '../../../services/sori_store.dart';
import '../../visit/home_visual_tokens.dart';
import '../../visit/visit_customer_picker_sheet.dart';
import 'program_closer_bar.dart';

class ProgramConfirmDecision {
  const ProgramConfirmDecision({
    required this.customer,
    required this.paymentStatus,
    required this.paidKrw,
    required this.method,
  });

  final Customer customer;
  final ProgramPaymentStatus paymentStatus;
  final int paidKrw;
  final ProgramPaymentMethod method;
}

/// C9/C11 — 등록 직전 재확인. 기본값은 미결제 (원장이 능동적으로 완료를 찍는다).
Future<ProgramConfirmDecision?> showProgramConfirmSheet({
  required BuildContext context,
  required SoriStore store,
  required ProgramQuote quote,
}) {
  return showModalBottomSheet<ProgramConfirmDecision>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HomeVisualTokens.heroCardFill,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => _ConfirmBody(store: store, quote: quote),
  );
}

class _ConfirmBody extends StatefulWidget {
  const _ConfirmBody({required this.store, required this.quote});

  final SoriStore store;
  final ProgramQuote quote;

  @override
  State<_ConfirmBody> createState() => _ConfirmBodyState();
}

class _ConfirmBodyState extends State<_ConfirmBody> {
  Customer? _customer;
  var _paid = false;
  var _method = ProgramPaymentMethod.cash;

  ProgramQuote get quote =>
      widget.store.findProgramQuote(widget.quote.id) ?? widget.quote;

  Future<void> _pickCustomer() async {
    final picked = await showVisitCustomerPickerSheet(
      context,
      store: widget.store,
      allowQuickCreate: true,
    );
    if (picked == null || !mounted) return;
    setState(() => _customer = picked);
  }

  void _submit() {
    final customer = _customer;
    if (customer == null) return;
    final due = quote.payableKrw;
    Navigator.pop(
      context,
      ProgramConfirmDecision(
        customer: customer,
        paymentStatus:
            _paid ? ProgramPaymentStatus.paid : ProgramPaymentStatus.unpaid,
        paidKrw: _paid ? due : 0,
        method: _method,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final q = quote;
    final side = q.chosen;
    final promos = ProgramPricing.stacked(
      q.promotionIds,
      widget.store.programPromotions,
    );
    final visits = ProgramPricing.membershipVisits(side.visitCount, promos);
    final credits = ProgramPricing.futureCredits(promos);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
        child: SingleChildScrollView(
          key: const Key('program-confirm-sheet'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HomeVisualTokens.caseCaptionDivider,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '이 구성으로 등록할까요',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              _line('관리', side.categoryName.trim().isEmpty ? '—' : side.categoryName),
              _line('패키지', side.name),
              _line('횟수', '$visits회'),
              if (side.lines.isNotEmpty)
                _line(
                  '구성',
                  side.lines.map((l) => l.label).take(4).join(' · '),
                ),
              if (q.uniquePromotionIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final id in q.uniquePromotionIds)
                      ProgramAppliedPromoChip(
                        title: widget.store.programPromotions
                                .where((p) => p.id == id)
                                .map((p) => p.title)
                                .firstOrNull ??
                            id,
                        qty: q.promotionQty[id] ?? 1,
                      ),
                  ],
                ),
              ],
              if (credits.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '다음 방문 쿠폰 ${credits.length}장 발급',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                '정가  ${ProgramPricing.formatKrw(q.listPriceKrw)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              if (q.benefitValueKrw > 0)
                Text(
                  '혜택  ${ProgramPricing.formatKrw(q.benefitValueKrw)}원',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              Text(
                '오늘 결제  ${ProgramPricing.formatKrw(q.payableKrw)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '결제 상태',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _Seg(
                      key: const Key('program-confirm-unpaid'),
                      label: '미결제',
                      selected: !_paid,
                      onTap: () => setState(() => _paid = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Seg(
                      key: const Key('program-confirm-paid'),
                      label: '결제 완료',
                      selected: _paid,
                      onTap: () => setState(() => _paid = true),
                    ),
                  ),
                ],
              ),
              if (_paid) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in ProgramPaymentMethod.values)
                      ChoiceChip(
                        key: Key('program-confirm-method-${m.dbValue}'),
                        label: Text(m.labelKo),
                        selected: _method == m,
                        onSelected: (_) => setState(() => _method = m),
                        showCheckmark: false,
                        selectedColor: HomeVisualTokens.canvasBg,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: HomeVisualTokens.programCloserFill,
                        ),
                        side: BorderSide(
                          color: _method == m
                              ? HomeVisualTokens.programCloserFill
                              : HomeVisualTokens.caseCaptionDivider,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                key: const Key('program-confirm-customer'),
                onPressed: _pickCustomer,
                style: OutlinedButton.styleFrom(
                  foregroundColor: HomeVisualTokens.programCloserFill,
                  side: const BorderSide(
                    color: HomeVisualTokens.programCloserFill,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _customer == null
                      ? '고객 선택'
                      : '${_customer!.name} · ${_customer!.phone}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: HomeVisualTokens.programDockH,
                child: FilledButton(
                  key: const Key('program-confirm-submit'),
                  onPressed: _customer == null ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: HomeVisualTokens.programCloserFill,
                    foregroundColor: HomeVisualTokens.programCloserOn,
                    disabledBackgroundColor: HomeVisualTokens.programCloserFill
                        .withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    '등록',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: HomeVisualTokens.dateIconColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? HomeVisualTokens.programCloserFill
          : HomeVisualTokens.canvasBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: selected
                  ? HomeVisualTokens.programCloserOn
                  : HomeVisualTokens.dateTextColor,
            ),
          ),
        ),
      ),
    );
  }
}
