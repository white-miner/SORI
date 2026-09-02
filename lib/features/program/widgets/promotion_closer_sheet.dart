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
  late final Set<String> _ids = {...widget.initialIds};

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final selected = widget.promotions.where((p) => _ids.contains(p.id));
    final benefit = ProgramPricing.benefitValue(selected);

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
                ? '총 ${ProgramPricing.formatKrw(benefit)}원 추가 혜택'
                : '사전 세팅한 혜택을 붙입니다',
            style: const TextStyle(
              fontSize: 12,
              color: HomeVisualTokens.dateIconColor,
            ),
          ),
          const SizedBox(height: 12),
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
                final on = _ids.contains(p.id);
                return Material(
                  color: HomeVisualTokens.canvasBg,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() {
                      if (on) {
                        _ids.remove(p.id);
                      } else {
                        _ids.add(p.id);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        children: [
                          Icon(
                            on
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 20,
                            color: on
                                ? HomeVisualTokens.programCheckFill
                                : HomeVisualTokens.dateIconColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
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
                          Text(
                            '${ProgramPricing.formatKrw(p.valueKrw)} 상당',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
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
              onPressed: () => Navigator.pop(context, _ids.toList()),
              style: FilledButton.styleFrom(
                backgroundColor: HomeVisualTokens.programCloserFill,
                foregroundColor: HomeVisualTokens.programCloserOn,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                '적용',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
