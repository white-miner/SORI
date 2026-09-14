import 'package:flutter/material.dart';

import 'chart_index_label.dart';
import 'chart_index_rail.dart';
import 'chart_workspace_state.dart';

class ChartFileRail extends StatelessWidget {
  const ChartFileRail({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  final List<FileRailItem> items;
  final String? selectedId;
  final ValueChanged<FileRailItem> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChartIndexRail<FileRailItem>(
      key: const Key('chart-file-rail'),
      items: items,
      selectedId: selectedId,
      itemId: (item) => item.id,
      onSelected: onSelected,
      labelBuilder: (context, item, selected) {
        final text = switch (item) {
          NewCustomerFileRailItem() => '신규',
          CustomerFileRailItem(:final label) => label,
        };
        return ChartIndexLabel(
          key: Key('chart-file-${item.id}'),
          text: text,
          selected: selected,
          compact: item is NewCustomerFileRailItem,
        );
      },
    );
  }
}
