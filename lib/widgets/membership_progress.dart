import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../theme/sori_tokens.dart';

/// 회원권 잔여 현황 — 프로그레스 바 + 뱃지 (양방향 동기화 표시용).
class MembershipProgressView extends StatelessWidget {
  const MembershipProgressView({
    super.key,
    required this.customer,
    this.compact = false,
    this.showServiceName = true,
  });

  final Customer customer;
  final bool compact;
  final bool showServiceName;

  @override
  Widget build(BuildContext context) {
    if (!customer.isMembershipCustomer) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: SoriTokens.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: SoriTokens.border),
        ),
        child: Text(
          '회원권 미등록',
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w600,
            color: SoriTokens.textSecondary,
          ),
        ),
      );
    }

    final accent = customer.isMembershipLow
        ? SoriTokens.warningText
        : SoriTokens.primary;
    final soft = customer.isMembershipLow
        ? SoriTokens.warningBg
        : SoriTokens.primarySoft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showServiceName &&
            (customer.primaryMembership?.serviceName.isNotEmpty == true ||
                customer.membershipServiceName.isNotEmpty)) ...[
          Text(
            customer.primaryMembership?.serviceName.isNotEmpty == true
                ? customer.primaryMembership!.serviceName
                : customer.membershipServiceName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: SoriTokens.textSecondary,
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
        ],
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: customer.membershipProgress,
                  minHeight: compact ? 6 : 8,
                  backgroundColor: soft,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: compact ? 3 : 4,
              ),
              decoration: BoxDecoration(
                color: soft,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                customer.membershipBadgeLabel,
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 고객 홈 상단용 프로필 + 회원권 카드.
class MembershipProfileCard extends StatelessWidget {
  const MembershipProfileCard({super.key, required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SoriTokens.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: SoriTokens.primarySoft,
                child: Text(
                  customer.name.isEmpty ? '?' : customer.name.characters.first,
                  style: const TextStyle(
                    color: SoriTokens.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer.phone,
                      style: const TextStyle(
                        fontSize: 12,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (customer.isMembershipLow)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: SoriTokens.warningBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '갱신 임박',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.warningText,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          MembershipProgressView(customer: customer),
        ],
      ),
    );
  }
}
