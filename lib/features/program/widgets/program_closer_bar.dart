import 'package:flutter/material.dart';

import '../../../models/program_sales.dart';
import '../../visit/home_visual_tokens.dart';

/// 단건 요약과 A/B 비교가 공유하는 클로징 3종 — 적용 가능 칩, 혜택 바, 버튼 행.
class ProgramAvailablePromos extends StatelessWidget {
  const ProgramAvailablePromos({super.key, required this.promotions});

  final List<ProgramPromotion> promotions;

  @override
  Widget build(BuildContext context) {
    if (promotions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Column(
        children: [
          const Text(
            '적용 가능 프로모션',
            key: Key('program-available-promos'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: HomeVisualTokens.dateIconColor,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final p in promotions)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: HomeVisualTokens.canvasBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${p.kind.labelKo} · ${p.title}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProgramBenefitBar extends StatelessWidget {
  const ProgramBenefitBar({
    super.key,
    required this.quote,
    required this.catalog,
  });

  final ProgramQuote quote;
  final List<ProgramPromotion> catalog;

  @override
  Widget build(BuildContext context) {
    final hasDiscount = quote.payableKrw < quote.listPriceKrw;
    final qty = quote.promotionQty;
    final order = quote.uniquePromotionIds;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        children: [
          Text(
            ProgramPricing.formatKrw(quote.listPriceKrw),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              decoration:
                  hasDiscount ? TextDecoration.lineThrough : TextDecoration.none,
              color: hasDiscount
                  ? HomeVisualTokens.programStrike
                  : HomeVisualTokens.dateTextColor,
            ),
          ),
          if (order.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (final id in order)
                    ProgramAppliedPromoChip(
                      key: Key('program-applied-promo-$id'),
                      title: catalog
                              .where((p) => p.id == id)
                              .map((p) => p.title)
                              .firstOrNull ??
                          id,
                      qty: qty[id] ?? 1,
                    ),
                ],
              ),
            ),
          if (quote.benefitValueKrw > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '총 ${ProgramPricing.formatKrw(quote.benefitValueKrw)}원 추가 혜택 적용됨',
                key: const Key('program-benefit-line'),
                style: const TextStyle(
                  fontSize: HomeVisualTokens.programBenefitSize,
                  fontWeight: FontWeight.w700,
                  color: HomeVisualTokens.dateTextColor,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '오늘 결제  ${ProgramPricing.formatKrw(quote.payableKrw)}',
              key: const Key('program-payable-line'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProgramAppliedPromoChip extends StatelessWidget {
  const ProgramAppliedPromoChip({
    super.key,
    required this.title,
    required this.qty,
  });

  final String title;
  final int qty;

  @override
  Widget build(BuildContext context) {
    final label = qty > 1 ? '$title ×$qty' : title;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: HomeVisualTokens.canvasBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: HomeVisualTokens.programCloserFill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: HomeVisualTokens.programCloserFill,
        ),
      ),
    );
  }
}

class ProgramCloserActions extends StatelessWidget {
  const ProgramCloserActions({
    super.key,
    required this.quote,
    required this.onOpenPromos,
    required this.onAccept,
  });

  final ProgramQuote quote;
  final VoidCallback onOpenPromos;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: HomeVisualTokens.programDockH,
              child: OutlinedButton.icon(
                key: const Key('program-closer-chip'),
                onPressed: onOpenPromos,
                style: OutlinedButton.styleFrom(
                  foregroundColor: HomeVisualTokens.programCloserFill,
                  side: const BorderSide(
                    color: HomeVisualTokens.programCloserFill,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.card_giftcard_outlined, size: 20),
                label: Text(
                  quote.promotionIds.isEmpty
                      ? '프로모션 적용'
                      : '프로모션 ${quote.promotionIds.length}건',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: HomeVisualTokens.programDockH,
              child: FilledButton(
                key: const Key('program-closer-accept'),
                onPressed: onAccept,
                style: FilledButton.styleFrom(
                  backgroundColor: HomeVisualTokens.programCloserFill,
                  foregroundColor: HomeVisualTokens.programCloserOn,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  '이 구성으로 등록',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
