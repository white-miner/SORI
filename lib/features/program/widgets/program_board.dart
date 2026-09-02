import 'package:flutter/material.dart';

import '../../../models/program_sales.dart';
import '../../visit/home_visual_tokens.dart';

/// 카테고리 1장. Collapsed 에는 앵커 가격만 트리에 올린다.
class ProgramCategoryCard extends StatelessWidget {
  const ProgramCategoryCard({
    super.key,
    required this.board,
    required this.expanded,
    required this.selectedIds,
    required this.onToggleExpand,
    required this.onToggleCheck,
  });

  final ProgramCategoryBoard board;
  final bool expanded;
  final List<String> selectedIds;
  final VoidCallback onToggleExpand;
  final ValueChanged<ProgramPackage> onToggleCheck;

  @override
  Widget build(BuildContext context) {
    final anchor = board.anchor;

    return Material(
      key: Key('program-category-${board.category.id}'),
      color: HomeVisualTokens.heroCardFill,
      elevation: 0,
      borderRadius: BorderRadius.circular(HomeVisualTokens.programCardRadius),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: AnimatedSize(
          duration: HomeVisualTokens.programExpandDuration,
          curve: HomeVisualTokens.programExpandCurve,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: onToggleExpand,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        board.category.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: HomeVisualTokens.dateTextColor,
                        ),
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: HomeVisualTokens.dateIconColor,
                    ),
                  ],
                ),
              ),
                if (!expanded && anchor != null)
                  InkWell(
                    onTap: onToggleExpand,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        if (board.category.subtitle.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              board.category.subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: HomeVisualTokens.dateIconColor,
                              ),
                            ),
                          ),
                        Text(
                          '${anchor.name}  ·  ${anchor.visitCount}회',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: HomeVisualTokens.dateTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ProgramPricing.formatKrw(anchor.listPriceKrw),
                          style: const TextStyle(
                            fontSize: HomeVisualTokens.programPriceSize,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                            height: 1.1,
                            color: HomeVisualTokens.dateTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '회당 ${ProgramPricing.formatKrw(anchor.unitPriceKrw)}',
                          style: const TextStyle(
                            fontSize: HomeVisualTokens.programUnitSize,
                            color: HomeVisualTokens.dateIconColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (expanded)
                  ...board.packages.map((pkg) {
                    final isAnchor = pkg.id == anchor?.id;
                    return _ExpandedRow(
                      package: pkg,
                      isAnchor: isAnchor,
                      checked: selectedIds.contains(pkg.id),
                      onToggleCheck: () => onToggleCheck(pkg),
                    );
                  }),
              ],
            ),
          ),
        ),
      );
  }
}

class _ExpandedRow extends StatelessWidget {
  const _ExpandedRow({
    required this.package,
    required this.isAnchor,
    required this.checked,
    required this.onToggleCheck,
  });

  final ProgramPackage package;
  final bool isAnchor;
  final bool checked;
  final VoidCallback onToggleCheck;

  @override
  Widget build(BuildContext context) {
    final devices = package.lines
        .where((l) => l.kind == ProgramLineKind.device)
        .map((l) => l.label)
        .join(' · ');

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: Key('program-check-${package.id}'),
            onTap: onToggleCheck,
            child: Padding(
              padding: const EdgeInsets.only(right: 10, top: 2),
              child: Icon(
                checked
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 22,
                color: checked
                    ? HomeVisualTokens.programCheckFill
                    : HomeVisualTokens.dateIconColor,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isAnchor)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: HomeVisualTokens.dateTextColor,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        '${package.name}  ${package.visitCount}회',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isAnchor ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      ProgramPricing.formatKrw(package.listPriceKrw),
                      style: TextStyle(
                        fontSize: isAnchor ? 16 : 14,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '회당 ${ProgramPricing.formatKrw(package.unitPriceKrw)}'
                  '${devices.isEmpty ? '' : '  ·  $devices'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: HomeVisualTokens.dateIconColor,
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
