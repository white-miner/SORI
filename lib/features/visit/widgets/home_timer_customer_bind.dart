import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/customer.dart';
import '../../../services/sori_store.dart';
import '../home_visual_tokens.dart';

/// Timer 탭 — 케어 실행 전 고객 차트 CRM 바인딩 미니 폼.
class HomeTimerCustomerBind extends StatelessWidget {
  const HomeTimerCustomerBind({
    super.key,
    required this.store,
    required this.enabled,
    required this.customer,
    required this.onEnabledChanged,
    required this.onPickCustomer,
    required this.onClear,
  });

  final SoriStore store;
  final bool enabled;
  final Customer? customer;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onPickCustomer;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final chart = customer == null ? null : store.latestChart(customer!.id);
    final age = customer?.koreanAge;
    final phone = customer?.phone.trim() ?? '';

    return Padding(
      key: const Key('home-timer-customer-bind'),
      padding: const EdgeInsets.fromLTRB(
        HomeVisualTokens.heroCardPaddingH,
        4,
        HomeVisualTokens.heroCardPaddingH,
        8,
      ),
      child: Material(
        color: HomeVisualTokens.heroCardFill,
        borderRadius: BorderRadius.circular(HomeVisualTokens.heroCardRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '고객 차트 연결',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: enabled,
                    activeTrackColor: const Color(0xFF34C759),
                    onChanged: onEnabledChanged,
                  ),
                ],
              ),
              if (enabled) ...[
                const SizedBox(height: 6),
                InkWell(
                  onTap: onPickCustomer,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFFE5E5EA),
                          child: Text(
                            customer == null || customer!.name.isEmpty
                                ? '?'
                                : customer!.name.substring(0, 1),
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF636366),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: customer == null
                              ? Text(
                                  '고객을 선택해 차트에 연결하세요',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF8E8E93),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      [
                                        if (chart != null)
                                          '${chart.visitNumber}회',
                                        customer!.name,
                                        if (age != null) '만 $age세',
                                      ].join(' · '),
                                      style: GoogleFonts.nunito(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF1C1C1E),
                                      ),
                                    ),
                                    if (phone.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        phone,
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF8E8E93),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                        if (customer != null)
                          IconButton(
                            tooltip: '연결 해제',
                            onPressed: onClear,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            visualDensity: VisualDensity.compact,
                          )
                        else
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF8E8E93),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
