import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';

/// 강사 펀딩 금융 증명 — "누적 세미나 N회 | 총 펀딩 NNN만 원".
class ShopFundingProofChip extends StatelessWidget {
  const ShopFundingProofChip({
    super.key,
    required this.totalSeminarCount,
    required this.totalFundingAmount,
    this.compact = false,
  });

  final int totalSeminarCount;
  final int totalFundingAmount;
  final bool compact;

  static String formatFundingManWon(int amount) {
    if (amount <= 0) return '0원';
    if (amount < 10000) return '${_comma(amount)}원';
    final man = amount / 10000;
    if (man >= 10 && man == man.roundToDouble()) {
      return '${_comma(man.round())}만 원';
    }
    if (man == man.roundToDouble()) {
      return '${man.round()}만 원';
    }
    return '${man.toStringAsFixed(1)}만 원';
  }

  static String _comma(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final fromEnd = s.length - i;
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return n < 0 ? '-$buf' : buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (totalSeminarCount <= 0 && totalFundingAmount <= 0) {
      return const SizedBox.shrink();
    }

    final label =
        '누적 세미나 $totalSeminarCount회 | 총 펀딩 ${formatFundingManWon(totalFundingAmount)}';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7ED), Color(0xFFFFFBEB)],
        ),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_rounded,
            size: compact ? 13 : 14,
            color: const Color(0xFFB45309),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFB45309),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// 프로필/상세 헤더용 — 티어 뱃지 옆 배치.
class ShopAuthorityBadgeRow extends StatelessWidget {
  const ShopAuthorityBadgeRow({
    super.key,
    required this.tierBadge,
    required this.totalSeminarCount,
    required this.totalFundingAmount,
    this.compact = false,
  });

  final Widget tierBadge;
  final int totalSeminarCount;
  final int totalFundingAmount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        tierBadge,
        ShopFundingProofChip(
          totalSeminarCount: totalSeminarCount,
          totalFundingAmount: totalFundingAmount,
          compact: compact,
        ),
      ],
    );
  }
}