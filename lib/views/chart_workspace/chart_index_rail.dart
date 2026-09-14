import 'package:flutter/material.dart';

/// 세 rail 공통 가로 인덱스. Wrap/Grid/TabBar 금지.
class ChartIndexRail<T> extends StatefulWidget {
  const ChartIndexRail({
    super.key,
    required this.items,
    required this.selectedId,
    required this.itemId,
    required this.labelBuilder,
    required this.onSelected,
    this.leading,
  });

  final List<T> items;
  final String? selectedId;
  final String Function(T item) itemId;
  final Widget Function(BuildContext context, T item, bool selected)
  labelBuilder;
  final ValueChanged<T> onSelected;
  final Widget? leading;

  @override
  State<ChartIndexRail<T>> createState() => _ChartIndexRailState<T>();
}

class _ChartIndexRailState<T> extends State<ChartIndexRail<T>> {
  final _controller = ScrollController();
  final _itemKeys = <String, GlobalKey>{};

  @override
  void didUpdateWidget(covariant ChartIndexRail<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    final id = widget.selectedId;
    if (id == null) return;
    final key = _itemKeys[id];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.35,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: widget.items.length + (widget.leading == null ? 0 : 1),
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (widget.leading != null && index == 0) {
            return widget.leading!;
          }

          final itemIndex = widget.leading == null ? index : index - 1;
          final item = widget.items[itemIndex];
          final id = widget.itemId(item);
          final isSelected = id == widget.selectedId;
          final key = _itemKeys.putIfAbsent(id, GlobalKey.new);

          return KeyedSubtree(
            key: key,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => widget.onSelected(item),
              child: widget.labelBuilder(context, item, isSelected),
            ),
          );
        },
      ),
    );
  }
}
