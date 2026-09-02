import 'package:flutter/material.dart';

import '../../../models/program_sales.dart';
import '../../visit/home_visual_tokens.dart';

Future<List<String>?> showPromotionCloserSheet({
  required BuildContext context,
  required List<ProgramPromotion> promotions,
  required List<String> selectedIds,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HomeVisualTokens.heroCardFill,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => _PromotionCloserBody(
      promotions: promotions,
      initialIds: selectedIds,
    ),
  );
}

class _PromotionCloserBody extends StatefulWidget {
  const _PromotionCloserBody({
    required this.promotions,
    required this.initialIds,
  });

  final List<ProgramPromotion> promotions;
  final List<String> initialIds;

  @override
  State<_PromotionCloserBody> createState() => _PromotionCloserBodyState();
}

class _PromotionCloserBodyState extends State<_PromotionCloserBody> {
  late final Map<String, int> _qty = ProgramPromoStack.qtyById(widget.initialIds);

  List<String> get _stackedIds => ProgramPromoStack.expand(
        _qty,
        order: widget.promotions.map((p) => p.id),
      );

  void _setQty(String id, int next) {
    setState(() {
      final n = next.clamp(0, ProgramPromoStack.maxQtyPerPromo).toInt();
      if (n <= 0) {
        _qty.remove(id);
      } else {
        _qty[id] = n;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final selected = ProgramPricing.stacked(_stackedIds, widget.promotions);
    final benefit = ProgramPricing.benefitValue(selected);
    final stackedCount = _stackedIds.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '프로모션 적용',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            benefit > 0
                ? '총 ${ProgramPricing.formatKrw(benefit)}원 추가 혜택 · $stackedCount건'
                : '여러 혜택을 겹쳐 붙일 수 있습니다',
            style: const TextStyle(
              fontSize: 12,
              color: HomeVisualTokens.dateIconColor,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.promotions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                '톱니에서 프로모션을 먼저 만드세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: HomeVisualTokens.dateIconColor,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.promotions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final p = widget.promotions[index];
                  final qty = _qty[p.id] ?? 0;
                  return Material(
                    key: Key('program-promo-row-${p.id}'),
                    color: HomeVisualTokens.canvasBg,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 8, 14, 8),
                      child: Row(
                        children: [
                          _QtyStepper(
                            promotionId: p.id,
                            qty: qty,
                            onMinus: () => _setQty(p.id, qty - 1),
                            onPlus: () => _setQty(p.id, qty + 1),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: InkWell(
                              onTap: () => _setQty(p.id, qty == 0 ? 1 : 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (p.subtitle.trim().isNotEmpty)
                                    Text(
                                      p.subtitle,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: HomeVisualTokens.dateIconColor,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            qty > 1
                                ? '${ProgramPricing.formatKrw(p.valueKrw * qty)} 상당'
                                : '${ProgramPricing.formatKrw(p.valueKrw)} 상당',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: HomeVisualTokens.programDockH,
            child: FilledButton(
              key: const Key('program-promo-apply'),
              onPressed: () => Navigator.pop(context, _stackedIds),
              style: FilledButton.styleFrom(
                backgroundColor: HomeVisualTokens.programCloserFill,
                foregroundColor: HomeVisualTokens.programCloserOn,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                stackedCount > 0 ? '$stackedCount건 적용' : '적용',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.promotionId,
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });

  final String promotionId;
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: Key('program-promo-minus-$promotionId'),
          visualDensity: VisualDensity.compact,
          onPressed: qty <= 0 ? null : onMinus,
          icon: const Icon(Icons.remove_rounded, size: 18),
        ),
        SizedBox(
          width: 22,
          child: Text(
            '$qty',
            key: Key('program-promo-qty-$promotionId'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        IconButton(
          key: Key('program-promo-plus-$promotionId'),
          visualDensity: VisualDensity.compact,
          onPressed: qty >= ProgramPromoStack.maxQtyPerPromo ? null : onPlus,
          icon: const Icon(Icons.add_rounded, size: 18),
        ),
      ],
    );
  }
}
