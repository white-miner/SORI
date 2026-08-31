import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/customer_chart.dart';
import '../theme/sori_tokens.dart';
import '../widgets/before_after_slider.dart';
import 'before_after_compare_sheet.dart';

/// B/A 비교 전용 풀스크린 — 사진 70~80% 지배, 핀치 줌, 글래스 컨트롤.
class BeforeAfterComparePage extends StatefulWidget {
  const BeforeAfterComparePage({
    super.key,
    required this.customerName,
    required this.charts,
  });

  final String customerName;
  final List<CustomerChart> charts;

  @override
  State<BeforeAfterComparePage> createState() => _BeforeAfterComparePageState();
}

class _BeforeAfterComparePageState extends State<BeforeAfterComparePage> {
  late final List<VisitPhotoSlot> _slots;
  late final Map<String, CustomerChart> _chartById;
  VisitPhotoSlot? _left;
  VisitPhotoSlot? _right;
  bool _useSlider = true;

  @override
  void initState() {
    super.initState();
    _slots = buildVisitPhotoSlots(widget.charts);
    _chartById = {for (final c in widget.charts) c.id: c};
    if (_slots.isNotEmpty) {
      _left = _slots.first;
      _right = _slots.length > 1 ? _slots.last : _slots.first;
    }
  }

  CustomerChart? _chartFor(VisitPhotoSlot? slot) {
    if (slot == null) return null;
    return _chartById[slot.chartId];
  }

  void _swapSides() {
    setState(() {
      final tmp = _left;
      _left = _right;
      _right = tmp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final empty = _slots.isEmpty;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      body: SafeArea(
        child: empty
            ? _EmptyState(customerName: widget.customerName)
            : wide
                ? Row(
                    children: [
                      Expanded(
                        flex: 73,
                        child: _CompareStage(
                          left: _left,
                          right: _right,
                          useSlider: _useSlider,
                          topBar: _TopGlassBar(
                            customerName: widget.customerName,
                            left: _left,
                            right: _right,
                            slots: _slots,
                            onLeftChanged: (v) => setState(() => _left = v),
                            onRightChanged: (v) => setState(() => _right = v),
                            onSwap: _swapSides,
                          ),
                          bottomBar: _BottomGlassBar(
                            useSlider: _useSlider,
                            onModeChanged: (v) => setState(() => _useSlider = v),
                            slots: _slots,
                            left: _left,
                            right: _right,
                            onPick: (slot) => setState(() => _right = slot),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 27,
                        child: _MetaRail(
                          left: _left,
                          right: _right,
                          leftChart: _chartFor(_left),
                          rightChart: _chartFor(_right),
                        ),
                      ),
                    ],
                  )
                : _CompareStage(
                    left: _left,
                    right: _right,
                    useSlider: _useSlider,
                    topBar: _TopGlassBar(
                      customerName: widget.customerName,
                      left: _left,
                      right: _right,
                      slots: _slots,
                      onLeftChanged: (v) => setState(() => _left = v),
                      onRightChanged: (v) => setState(() => _right = v),
                      onSwap: _swapSides,
                    ),
                    bottomBar: _BottomGlassBar(
                      useSlider: _useSlider,
                      onModeChanged: (v) => setState(() => _useSlider = v),
                      slots: _slots,
                      left: _left,
                      right: _right,
                      onPick: (slot) => setState(() => _right = slot),
                    ),
                  ),
      ),
    );
  }
}

Future<void> openBeforeAfterComparePage({
  required BuildContext context,
  required String customerName,
  required List<CustomerChart> charts,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => BeforeAfterComparePage(
        customerName: customerName,
        charts: charts,
      ),
    ),
  );
}

class _CompareStage extends StatelessWidget {
  const _CompareStage({
    required this.left,
    required this.right,
    required this.useSlider,
    required this.topBar,
    required this.bottomBar,
  });

  final VisitPhotoSlot? left;
  final VisitPhotoSlot? right;
  final bool useSlider;
  final Widget topBar;
  final Widget bottomBar;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 72, 8, 88),
            child: left != null && right != null
                ? _ZoomableCompareBody(
                    left: left!,
                    right: right!,
                    useSlider: useSlider,
                  )
                : const SizedBox.shrink(),
          ),
        ),
        Positioned(top: 8, left: 8, right: 8, child: topBar),
        Positioned(bottom: 8, left: 8, right: 8, child: bottomBar),
      ],
    );
  }
}

class _ZoomableCompareBody extends StatelessWidget {
  const _ZoomableCompareBody({
    required this.left,
    required this.right,
    required this.useSlider,
  });

  final VisitPhotoSlot left;
  final VisitPhotoSlot right;
  final bool useSlider;

  Widget _pane(VisitPhotoSlot slot) {
    return ChartImagePane(
      url: slot.url,
      fallbackLabel: slot.shortLabel,
      tone: SoriTokens.textSecondary,
      fit: BoxFit.contain,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        if (useSlider) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            panEnabled: true,
            clipBehavior: Clip.none,
            boundaryMargin: const EdgeInsets.all(120),
            child: SizedBox(
              width: w,
              height: h,
              child: BeforeAfterSlider(
                height: h,
                maxHeight: h,
                dragHandleOnly: true,
                borderRadius: BorderRadius.circular(20),
                before: _pane(left),
                after: _pane(right),
              ),
            ),
          );
        }

        return Row(
          children: [
            Expanded(
              child: _ZoomPane(
                label: left.label,
                child: _pane(left),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _ZoomPane(
                label: right.label,
                child: _pane(right),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ZoomPane extends StatelessWidget {
  const _ZoomPane({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            panEnabled: true,
            clipBehavior: Clip.none,
            boundaryMargin: const EdgeInsets.all(80),
            child: child,
          ),
          Positioned(
            left: 10,
            top: 10,
            child: _GlassChip(text: label),
          ),
        ],
      ),
    );
  }
}

class _TopGlassBar extends StatelessWidget {
  const _TopGlassBar({
    required this.customerName,
    required this.left,
    required this.right,
    required this.slots,
    required this.onLeftChanged,
    required this.onRightChanged,
    required this.onSwap,
  });

  final String customerName;
  final VisitPhotoSlot? left;
  final VisitPhotoSlot? right;
  final List<VisitPhotoSlot> slots;
  final ValueChanged<VisitPhotoSlot> onLeftChanged;
  final ValueChanged<VisitPhotoSlot> onRightChanged;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.fromLTRB(6, 6, 10, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: Colors.white,
            tooltip: '닫기',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$customerName · B/A 비교',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _CompactSlotSelect(
                        label: '왼쪽',
                        selected: left,
                        options: slots,
                        onChanged: onLeftChanged,
                      ),
                    ),
                    IconButton(
                      onPressed: onSwap,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                      color: Colors.white70,
                      tooltip: '좌우 바꾸기',
                      visualDensity: VisualDensity.compact,
                    ),
                    Expanded(
                      child: _CompactSlotSelect(
                        label: '오른쪽',
                        selected: right,
                        options: slots,
                        onChanged: onRightChanged,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomGlassBar extends StatelessWidget {
  const _BottomGlassBar({
    required this.useSlider,
    required this.onModeChanged,
    required this.slots,
    required this.left,
    required this.right,
    required this.onPick,
  });

  final bool useSlider;
  final ValueChanged<bool> onModeChanged;
  final List<VisitPhotoSlot> slots;
  final VisitPhotoSlot? left;
  final VisitPhotoSlot? right;
  final ValueChanged<VisitPhotoSlot> onPick;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 260,
            child: SegmentedButton<bool>(
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return Colors.white.withValues(alpha: 0.12);
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return SoriTokens.textPrimary;
                  }
                  return Colors.white;
                }),
              ),
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('슬라이더', style: TextStyle(fontSize: 12)),
                  icon: Icon(Icons.compare_arrows, size: 15),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('나란히', style: TextStyle(fontSize: 12)),
                  icon: Icon(Icons.view_column_outlined, size: 15),
                ),
              ],
              selected: {useSlider},
              onSelectionChanged: (s) => onModeChanged(s.first),
            ),
          ),
          if (left != null && right != null) ...[
            const SizedBox(height: 8),
            Text(
              '${left!.shortLabel}  ↔  ${right!.shortLabel}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: slots.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, index) {
                final slot = slots[index];
                final active =
                    left?.key == slot.key || right?.key == slot.key;
                return ActionChip(
                  label: Text(
                    slot.shortLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: active ? SoriTokens.textPrimary : Colors.white,
                    ),
                  ),
                  onPressed: () => onPick(slot),
                  backgroundColor: active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.14),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRail extends StatelessWidget {
  const _MetaRail({
    required this.left,
    required this.right,
    required this.leftChart,
    required this.rightChart,
  });

  final VisitPhotoSlot? left;
  final VisitPhotoSlot? right;
  final CustomerChart? leftChart;
  final CustomerChart? rightChart;

  @override
  Widget build(BuildContext context) {
    final focus = rightChart ?? leftChart;
    final focusSlot = right ?? left;

    return Container(
      color: SoriTokens.surface,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            focusSlot == null
                ? '회차 정보'
                : '${focusSlot.visitNumber}회차',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (focus != null &&
              focus.careName.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              focus.careName.trim(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: SoriTokens.textSecondary,
              ),
            ),
          ],
          if (focus != null && focus.concernChips.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: focus.concernChips
                  .map(
                    (t) => Chip(
                      label: Text(t, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: SoriTokens.surface,
                      side: const BorderSide(color: SoriTokens.border),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (focus != null &&
              focus.treatmentSummary.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '시술 요약',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: SoriTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              focus.treatmentSummary.trim(),
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const Spacer(),
          if (left != null && right != null)
            Text(
              '비교: ${left!.shortLabel} ↔ ${right!.shortLabel}',
              style: const TextStyle(
                fontSize: 12,
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            '핀치로 확대해 눈가·트러블 부위를 비교하세요.',
            style: TextStyle(
              fontSize: 11.5,
              color: SoriTokens.textSecondary.withValues(alpha: 0.9),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactSlotSelect extends StatelessWidget {
  const _CompactSlotSelect({
    required this.label,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final VisitPhotoSlot? selected;
  final List<VisitPhotoSlot> options;
  final ValueChanged<VisitPhotoSlot> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 2),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selected?.key,
              isExpanded: true,
              dropdownColor: const Color(0xFF1C1C1E),
              icon: Icon(
                Icons.expand_more_rounded,
                color: Colors.white.withValues(alpha: 0.8),
                size: 18,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              items: [
                for (final slot in options)
                  DropdownMenuItem(
                    value: slot.key,
                    child: Text(
                      slot.shortLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (key) {
                if (key == null) return;
                final match = options.where((s) => s.key == key);
                if (match.isNotEmpty) onChanged(match.first);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: Colors.black.withValues(alpha: 0.45),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.customerName});

  final String customerName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                '$customerName님의 비교할 회차 사진이 아직 없습니다.\n'
                '차트에 Before/After를 첨부하면 회차별로 비교할 수 있어요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.45,
                  color: Colors.white.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
