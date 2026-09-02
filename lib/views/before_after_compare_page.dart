import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/customer_chart.dart';
import '../theme/sori_tokens.dart';
import '../widgets/before_after_slider.dart';
import 'before_after_compare_sheet.dart';

/// B/A 비교 전용 풀스크린.
///
/// 세로는 사진 위에 글래스 컨트롤을 얹고, 가로는 사진을 좌측 70~75%에 단독
/// 배치한 뒤 모든 조작을 우측 패널로 보낸다. 선택은 서비스 메뉴 → 회차 B/A
/// 의 2 depth. 피드에서 넘긴 [initialChartId]가 있으면 그 차트 사진부터 연다.
class BeforeAfterComparePage extends StatefulWidget {
  const BeforeAfterComparePage({
    super.key,
    required this.customerName,
    required this.charts,
    this.initialChartId,
    this.initialCareName,
  });

  final String customerName;
  final List<CustomerChart> charts;

  /// 피드에서 확대 버튼을 누른 그 차트. 없으면 해당 프로그램의 첫·마지막.
  final String? initialChartId;
  final String? initialCareName;

  @override
  State<BeforeAfterComparePage> createState() => _BeforeAfterComparePageState();
}

class _BeforeAfterComparePageState extends State<BeforeAfterComparePage> {
  late final List<VisitPhotoSlot> _slots;
  late final List<CareProgramGroup> _programs;
  late final Map<String, CustomerChart> _chartById;
  late String _programKey;
  VisitPhotoSlot? _left;
  VisitPhotoSlot? _right;
  bool _useSlider = true;

  @override
  void initState() {
    super.initState();
    _slots = buildVisitPhotoSlots(widget.charts);
    _programs = groupVisitPhotoSlotsByProgram(_slots);
    _chartById = {for (final c in widget.charts) c.id: c};
    final seed = resolveCompareViewerSeed(
      slots: _slots,
      initialChartId: widget.initialChartId,
      initialCareName: widget.initialCareName,
    );
    _programKey = seed.programKey;
    _left = seed.left;
    _right = seed.right;
  }

  List<VisitPhotoSlot> get _scopedSlots => slotsForProgram(
        slots: _slots,
        programKey: _programKey,
      );

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

  void _selectProgram(String key) {
    if (key == _programKey) return;
    final seed = resolveCompareViewerSeed(
      slots: _slots,
      initialCareName: key,
    );
    setState(() {
      _programKey = seed.programKey;
      _left = seed.left;
      _right = seed.right;
    });
  }

  @override
  Widget build(BuildContext context) {
    final empty = _slots.isEmpty;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      body: empty
          ? SafeArea(child: _EmptyState(customerName: widget.customerName))
          : landscape
              ? _buildLandscape()
              : SafeArea(child: _buildPortrait()),
    );
  }

  /// 좌측 73%는 사진만, 우측 27%에 조작 UI를 전부 모은다.
  Widget _buildLandscape() {
    return Row(
      children: [
        Expanded(
          flex: 73,
          child: _CompareStage(
            key: const Key('ba-compare-photo-stage'),
            left: _left,
            right: _right,
            useSlider: _useSlider,
          ),
        ),
        Expanded(
          flex: 27,
          child: _SideControlPanel(
            key: const Key('ba-compare-side-panel'),
            customerName: widget.customerName,
            programs: _programs,
            programKey: _programKey,
            slots: _scopedSlots,
            left: _left,
            right: _right,
            useSlider: _useSlider,
            leftChart: _chartFor(_left),
            rightChart: _chartFor(_right),
            onProgramChanged: _selectProgram,
            onLeftChanged: (v) => setState(() => _left = v),
            onRightChanged: (v) => setState(() => _right = v),
            onSwap: _swapSides,
            onModeChanged: (v) => setState(() => _useSlider = v),
            onPick: (slot) => setState(() => _right = slot),
          ),
        ),
      ],
    );
  }

  Widget _buildPortrait() {
    return _CompareStage(
      key: const Key('ba-compare-photo-stage'),
      left: _left,
      right: _right,
      useSlider: _useSlider,
      topBar: _TopGlassBar(
        customerName: widget.customerName,
        programs: _programs,
        programKey: _programKey,
        left: _left,
        right: _right,
        slots: _scopedSlots,
        onProgramChanged: _selectProgram,
        onLeftChanged: (v) => setState(() => _left = v),
        onRightChanged: (v) => setState(() => _right = v),
        onSwap: _swapSides,
      ),
      bottomBar: _BottomGlassBar(
        useSlider: _useSlider,
        onModeChanged: (v) => setState(() => _useSlider = v),
        slots: _scopedSlots,
        left: _left,
        right: _right,
        onPick: (slot) => setState(() => _right = slot),
      ),
    );
  }
}

Future<void> openBeforeAfterComparePage({
  required BuildContext context,
  required String customerName,
  required List<CustomerChart> charts,
  String? initialChartId,
  String? initialCareName,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => BeforeAfterComparePage(
        customerName: customerName,
        charts: charts,
        initialChartId: initialChartId,
        initialCareName: initialCareName,
      ),
    ),
  );
}

class _CompareStage extends StatelessWidget {
  const _CompareStage({
    super.key,
    required this.left,
    required this.right,
    required this.useSlider,
    this.topBar,
    this.bottomBar,
  });

  final VisitPhotoSlot? left;
  final VisitPhotoSlot? right;
  final bool useSlider;
  final Widget? topBar;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final overlay = topBar != null || bottomBar != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Padding(
            // 가로 모드에서는 상·하 바를 비우므로 사진이 스테이지를 채운다.
            padding: overlay
                ? const EdgeInsets.fromLTRB(8, 118, 8, 96)
                : const EdgeInsets.all(8),
            child: left != null && right != null
                ? _ZoomableCompareBody(
                    left: left!,
                    right: right!,
                    useSlider: useSlider,
                  )
                : const SizedBox.shrink(),
          ),
        ),
        if (topBar != null)
          Positioned(top: 8, left: 8, right: 8, child: topBar!),
        if (bottomBar != null)
          Positioned(bottom: 8, left: 8, right: 8, child: bottomBar!),
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
              child: _ZoomPane(label: left.label, child: _pane(left)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _ZoomPane(label: right.label, child: _pane(right)),
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

class _SideControlPanel extends StatelessWidget {
  const _SideControlPanel({
    super.key,
    required this.customerName,
    required this.programs,
    required this.programKey,
    required this.slots,
    required this.left,
    required this.right,
    required this.useSlider,
    required this.leftChart,
    required this.rightChart,
    required this.onProgramChanged,
    required this.onLeftChanged,
    required this.onRightChanged,
    required this.onSwap,
    required this.onModeChanged,
    required this.onPick,
  });

  final String customerName;
  final List<CareProgramGroup> programs;
  final String programKey;
  final List<VisitPhotoSlot> slots;
  final VisitPhotoSlot? left;
  final VisitPhotoSlot? right;
  final bool useSlider;
  final CustomerChart? leftChart;
  final CustomerChart? rightChart;
  final ValueChanged<String> onProgramChanged;
  final ValueChanged<VisitPhotoSlot> onLeftChanged;
  final ValueChanged<VisitPhotoSlot> onRightChanged;
  final VoidCallback onSwap;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<VisitPhotoSlot> onPick;

  @override
  Widget build(BuildContext context) {
    final focus = rightChart ?? leftChart;
    return ColoredBox(
      color: const Color(0xFF141416),
      child: SafeArea(
        left: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    color: Colors.white,
                    tooltip: '닫기',
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: Text(
                      '$customerName · B/A 비교',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _DarkSelect<String>(
                label: '서비스 메뉴',
                value: programs.any((p) => p.key == programKey)
                    ? programKey
                    : (programs.isEmpty ? null : programs.first.key),
                items: [
                  for (final p in programs)
                    (value: p.key, label: p.label),
                ],
                onChanged: onProgramChanged,
              ),
              const SizedBox(height: 10),
              _DarkSelect<String>(
                label: '왼쪽',
                value: left?.key,
                items: [
                  for (final s in slots) (value: s.key, label: s.shortLabel),
                ],
                onChanged: (key) {
                  final match = slots.where((s) => s.key == key);
                  if (match.isNotEmpty) onLeftChanged(match.first);
                },
              ),
              Center(
                child: IconButton(
                  onPressed: onSwap,
                  icon: const Icon(Icons.swap_vert_rounded, size: 20),
                  color: Colors.white70,
                  tooltip: '좌우 바꾸기',
                  visualDensity: VisualDensity.compact,
                ),
              ),
              _DarkSelect<String>(
                label: '오른쪽',
                value: right?.key,
                items: [
                  for (final s in slots) (value: s.key, label: s.shortLabel),
                ],
                onChanged: (key) {
                  final match = slots.where((s) => s.key == key);
                  if (match.isNotEmpty) onRightChanged(match.first);
                },
              ),
              const SizedBox(height: 12),
              _ModeToggle(useSlider: useSlider, onChanged: onModeChanged),
              if (left != null && right != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${left!.shortLabel}  ↔  ${right!.shortLabel}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final slot in slots)
                          _SlotChip(
                            slot: slot,
                            active: left?.key == slot.key ||
                                right?.key == slot.key,
                            onTap: () => onPick(slot),
                          ),
                      ],
                    ),
                    if (focus != null &&
                        focus.treatmentSummary.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        '시술 요약',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        focus.treatmentSummary.trim(),
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopGlassBar extends StatelessWidget {
  const _TopGlassBar({
    required this.customerName,
    required this.programs,
    required this.programKey,
    required this.left,
    required this.right,
    required this.slots,
    required this.onProgramChanged,
    required this.onLeftChanged,
    required this.onRightChanged,
    required this.onSwap,
  });

  final String customerName;
  final List<CareProgramGroup> programs;
  final String programKey;
  final VisitPhotoSlot? left;
  final VisitPhotoSlot? right;
  final List<VisitPhotoSlot> slots;
  final ValueChanged<String> onProgramChanged;
  final ValueChanged<VisitPhotoSlot> onLeftChanged;
  final ValueChanged<VisitPhotoSlot> onRightChanged;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.fromLTRB(6, 6, 10, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                color: Colors.white,
                tooltip: '닫기',
              ),
              Expanded(
                child: Text(
                  '$customerName · B/A 비교',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          _DarkSelect<String>(
            label: '서비스 메뉴',
            value: programs.any((p) => p.key == programKey)
                ? programKey
                : (programs.isEmpty ? null : programs.first.key),
            items: [
              for (final p in programs) (value: p.key, label: p.label),
            ],
            onChanged: onProgramChanged,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _DarkSelect<String>(
                  label: '왼쪽',
                  value: left?.key,
                  items: [
                    for (final s in slots)
                      (value: s.key, label: s.shortLabel),
                  ],
                  onChanged: (key) {
                    final match = slots.where((s) => s.key == key);
                    if (match.isNotEmpty) onLeftChanged(match.first);
                  },
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
                child: _DarkSelect<String>(
                  label: '오른쪽',
                  value: right?.key,
                  items: [
                    for (final s in slots)
                      (value: s.key, label: s.shortLabel),
                  ],
                  onChanged: (key) {
                    final match = slots.where((s) => s.key == key);
                    if (match.isNotEmpty) onRightChanged(match.first);
                  },
                ),
              ),
            ],
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
          _ModeToggle(useSlider: useSlider, onChanged: onModeChanged),
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
                return _SlotChip(
                  slot: slot,
                  active: left?.key == slot.key || right?.key == slot.key,
                  onTap: () => onPick(slot),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.useSlider, required this.onChanged});

  final bool useSlider;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModeChip(
            label: '슬라이더',
            icon: Icons.compare_arrows,
            selected: useSlider,
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _ModeChip(
            label: '나란히',
            icon: Icons.view_column_outlined,
            selected: !useSlider,
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? SoriTokens.textPrimary : Colors.white,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? SoriTokens.textPrimary : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.active,
    required this.onTap,
  });

  final VisitPhotoSlot slot;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        slot.shortLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? SoriTokens.textPrimary : Colors.white,
        ),
      ),
      onPressed: onTap,
      backgroundColor:
          active ? Colors.white : Colors.white.withValues(alpha: 0.14),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _DarkSelect<T> extends StatelessWidget {
  const _DarkSelect({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<({T value, String label})> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final keys = items.map((e) => e.value).toSet();
    final selected = value != null && keys.contains(value) ? value : null;
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
            child: DropdownButton<T>(
              value: selected,
              isExpanded: true,
              hint: const Text(
                '선택',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              dropdownColor: const Color(0xFF1C1C1E),
              icon: Icon(
                Icons.expand_more_rounded,
                color: Colors.white.withValues(alpha: 0.8),
                size: 18,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              items: [
                for (final item in items)
                  DropdownMenuItem(
                    value: item.value,
                    child: Text(
                      item.label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
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
