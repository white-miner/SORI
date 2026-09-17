import 'package:flutter/material.dart';

import 'chart_index_label.dart';
import 'chart_index_palette.dart';
import 'chart_index_rail.dart';
import 'chart_workspace_state.dart';

class ChartDrawerRail extends StatelessWidget {
  const ChartDrawerRail({
    super.key,
    required this.drawers,
    required this.selectedDrawerId,
    required this.onSelected,
  });

  final List<ChartDrawerViewModel> drawers;
  final String? selectedDrawerId;
  final ValueChanged<ChartDrawerViewModel> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChartIndexRail<ChartDrawerViewModel>(
      key: const Key('chart-drawer-rail'),
      items: drawers,
      selectedId: selectedDrawerId,
      itemId: (d) => d.id,
      onSelected: onSelected,
      labelBuilder: (context, drawer, selected) {
        return ChartIndexLabel(
          key: Key('chart-drawer-${drawer.id}'),
          text: drawer.label,
          selected: selected,
          // 서랍은 번호가 없다 — 끝자리 팔레트와 무관한 고정색.
          baseColor: kChartIndexNoNumberColor,
        );
      },
    );
  }
}
