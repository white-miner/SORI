import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/seminar_class.dart';
import '../models/seminar_class_detail.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

enum _PaymentMethod { card, kakaoPay }

/// B2B 세미나 에스크로 결제 Checkout 바텀시트.
class SeminarCheckoutBottomSheet extends StatefulWidget {
  const SeminarCheckoutBottomSheet({
    super.key,
    required this.store,
    required this.detail,
    required this.dateFmt,
    required this.priceFmt,
  });

  final SoriStore store;
  final SeminarClassDetail detail;
  final DateFormat dateFmt;
  final NumberFormat priceFmt;

  static Future<bool> show(
    BuildContext context, {
    required SoriStore store,
    required SeminarClassDetail detail,
    required DateFormat dateFmt,
    required NumberFormat priceFmt,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SeminarCheckoutBottomSheet(
          store: store,
          detail: detail,
          dateFmt: dateFmt,
          priceFmt: priceFmt,
        ),
      ),
    ).then((value) => value == true);
  }

  @override
  State<SeminarCheckoutBottomSheet> createState() =>
      _SeminarCheckoutBottomSheetState();
}

class _SeminarCheckoutBottomSheetState extends State<SeminarCheckoutBottomSheet> {
  _PaymentMethod _method = _PaymentMethod.card;
  bool _refundAgreed = false;
  bool _paying = false;

  SeminarClassDetail get detail => widget.detail;
  SeminarClass get cls => detail.seminarClass;

  String get _directorLabel {
    final owner = detail.directorShop.ownerName?.trim();
    if (owner != null && owner.isNotEmpty) return owner;
    return detail.directorShop.name;
  }

  String get _dateLabel => cls.eventDate == null
      ? '일정 미정'
      : widget.dateFmt.format(cls.eventDate!.toLocal());

  Future<void> _submitPayment() async {
    if (!_refundAgreed || _paying) return;

    setState(() => _paying = true);
    final enrollId = await widget.store.enrollSeminarClass(
      classId: cls.id,
      enrollorShopId: widget.store.shop.id,
    );

    if (!mounted) return;

    if (enrollId == null || enrollId.isEmpty) {
      setState(() => _paying = false);
      final msg = widget.store.lastError?.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg != null && msg.isNotEmpty
                ? msg
                : '결제에 실패했습니다. 잠시 후 다시 시도해 주세요.',
          ),
          backgroundColor: SoriTokens.primaryDark,
        ),
      );
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
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
              '에스크로 결제',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            _SummaryCard(
              title: cls.title,
              director: _directorLabel,
              dateLabel: _dateLabel,
              priceLabel: '${widget.priceFmt.format(cls.price)}원',
            ),
            const SizedBox(height: 12),
            const _EscrowTrustBanner(),
            const SizedBox(height: 16),
            const Text(
              '결제 수단',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _PaymentMethodTile(
              selected: _method == _PaymentMethod.card,
              icon: Icons.credit_card_rounded,
              label: '신용·체크카드',
              subtitle: '국내 모든 카드 (목업)',
              tint: SoriTokens.primary,
              onTap: _paying
                  ? null
                  : () => setState(() => _method = _PaymentMethod.card),
            ),
            const SizedBox(height: 8),
            _PaymentMethodTile(
              selected: _method == _PaymentMethod.kakaoPay,
              icon: Icons.account_balance_wallet_outlined,
              label: '카카오페이',
              subtitle: '간편 결제 (목업)',
              tint: const Color(0xFFFEE500),
              iconColor: const Color(0xFF191919),
              onTap: _paying
                  ? null
                  : () => setState(() => _method = _PaymentMethod.kakaoPay),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _refundAgreed,
              onChanged: _paying
                  ? null
                  : (v) => setState(() => _refundAgreed = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                '환불·취소 규정 및 에스크로 보관 정책에 동의합니다.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              subtitle: Text(
                '교육 시작 24시간 전까지 전액 환불, 이후에는 에스크로 규정에 따릅니다.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade600,
                  height: 1.35,
                ),
              ),
              activeColor: SoriTokens.primary,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _refundAgreed && !_paying ? _submitPayment : null,
              style: FilledButton.styleFrom(
                backgroundColor: SoriTokens.primary,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _paying
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      '${widget.priceFmt.format(cls.price)}원 결제하기',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            Text(
              'SORI는 통신판매중개자이며, 세미나의 내용과 품질에 대한 책임은 호스트에게 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.4,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.director,
    required this.dateLabel,
    required this.priceLabel,
  });

  final String title;
  final String director;
  final String dateLabel;
  final String priceLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SoriTokens.border,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SoriTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _SummaryRow(icon: Icons.person_outline, label: director),
          const SizedBox(height: 4),
          _SummaryRow(icon: Icons.event_outlined, label: dateLabel),
          const Divider(height: 20),
          Row(
            children: [
              const Text(
                '최종 결제 금액',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: SoriTokens.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                priceLabel,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: SoriTokens.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }
}

class _EscrowTrustBanner extends StatelessWidget {
  const _EscrowTrustBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SoriTokens.primarySoft,
            const Color(0xFF152033),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SoriTokens.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: SoriTokens.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: SoriTokens.primary.withValues(alpha: 0.12),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Text('🛡️', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SORI 에스크로 안심 결제',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: SoriTokens.primary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '수강 대금은 교육 완료 시까지 SORI가 안전하게 보호합니다',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: SoriTokens.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.selected,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.tint,
    required this.onTap,
    this.iconColor,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final String subtitle;
  final Color tint;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? tint.withValues(alpha: 0.15) : SoriTokens.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? tint : SoriTokens.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor ?? tint, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected ? tint : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
