import 'package:flutter/material.dart';

import 'chart_index_label.dart';
import 'chart_index_palette.dart';
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

  /// 이 항목의 색. 신규 작성은 번호가 없어 고정색, Today는 오늘 실제 vN의
  /// 끝자리색을 그대로 상속, vN은 자기 끝자리 색.
  static Color _baseColorFor(VisitRailItem item) {
    final chart = item.chart;
    if (chart == null) return kChartIndexNoNumberColor;
    return ChartIndexPaletteStore.instance.colorForNumber(chart.visitNumber);
  }

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
          baseColor: _baseColorFor(item),
        );
      },
    );
  }
}
