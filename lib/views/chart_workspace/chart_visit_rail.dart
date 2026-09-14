import 'package:flutter/material.dart';

import 'chart_index_label.dart';
import 'chart_index_rail.dart';
import 'chart_workspace_state.dart';

class ChartVisitRail extends StatelessWidget {
  const ChartVisitRail({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  final List<VisitRailItem> items;
  final String? selectedId;
  final ValueChanged<VisitRailItem> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChartIndexRail<VisitRailItem>(
      key: const Key('chart-visit-rail'),
      items: items,
      selectedId: selectedId,
      itemId: (item) => item.id,
      onSelected: onSelected,
      labelBuilder: (context, item, selected) {
        return ChartIndexLabel(
          key: Key('chart-visit-${item.id}'),
          text: item.label,
          selected: selected,
        );
      },
    );
  }
}
