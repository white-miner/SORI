import 'dart:ui';

import 'package:flutter/material.dart';

import '../features/visit/widgets/ba_story_strip.dart';
import '../models/customer_chart.dart';
import '../theme/sori_tokens.dart';
import '../widgets/before_after_slider.dart';
import 'before_after_compare_sheet.dart';

/// B/A 비교 전용 풀스크린.
///
/// 사진은 스테이지를 꽉 채운다. 슬라이더는 홈 피드와 같은
/// [BeforeAfterSlider] (전면 가로 드래그, InteractiveViewer 없음).
/// 줌은 핀치가 아니라 [+][-] 고정 배율이다.
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

  /// 버튼 줌 배율. 핀치 제스처는 쓰지 않는다.
  static const List<double> zoomSteps = [1.0, 1.5, 2.0];

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
  BaCompareBindSide _bindSide = BaCompareBindSide.right;
  int _zoomIndex = 0;

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

  List<VisitPhotoSlot> get _scopedSlots =>
      slotsForProgram(slots: _slots, programKey: _programKey);

  double get _zoom => BeforeAfterComparePage.zoomSteps[_zoomIndex];

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
    final seed = resolveCompareViewerSeed(slots: _slots, initialCareName: key);
    setState(() {
      _programKey = seed.programKey;
      _left = seed.left;
      _right = seed.right;
      _zoomIndex = 0;
    });
  }

  void _setLeft(VisitPhotoSlot slot) {
    setState(() {
      _left = slot;
      _bindSide = BaCompareBindSide.left;
    });
  }

  void _setRight(VisitPhotoSlot slot) {
    setState(() {
      _right = slot;
      _bindSide = BaCompareBindSide.right;
    });
  }

  void _bind(VisitPhotoSlot slot) {
    setState(() {
      if (_bindSide == BaCompareBindSide.left) {
        _left = slot;
      } else {
        _right = slot;
      }
    });
  }

  void _zoomIn() {
    if (_zoomIndex >= BeforeAfterComparePage.zoomSteps.length - 1) return;
    setState(() => _zoomIndex++);
  }

  void _zoomOut() {
    if (_zoomIndex <= 0) return;
    setState(() => _zoomIndex--);
  }

  Widget _storyStrip() {
    return BaStoryStrip(
      key: const Key('ba-compare-story-strip'),
      slots: _scopedSlots,
      left: _left,
      right: _right,
      bindSide: _bindSide,
      onBind: _bind,
    );
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
          : _buildPortrait(),
    );
  }

  /// 좌측 78%는 사진만, 우측 22%에 조작 UI를 모은다.
  Widget _buildLandscape() {
    return Row(
      children: [
        Expanded(
          flex: 78,
          child: _CompareStage(
            key: const Key('ba-compare-photo-stage'),
            left: _left,
            right: _right,
            useSlider: _useSlider,
            zoom: _zoom,
            onZoomIn: _zoomIn,
            onZoomOut: _zoomOut,
            bottomBar: _storyStrip(),
          ),
        ),
        Expanded(
          flex: 22,
          child: _SideControlPanel(
            key: const Key('ba-compare-side-panel'),
            customerName: widget.customerName,
            programs: _programs,
            programKey: _programKey,
            slots: _scopedSlots,
            left: _left,
            right: _right,
            useSlider: _useSlider,
            bindSide: _bindSide,
            leftChart: _chartFor(_left),
            rightChart: _chartFor(_right),
            onProgramChanged: _selectProgram,
            onLeftChanged: _setLeft,
            onRightChanged: _setRight,
            onSwap: _swapSides,
            onModeChanged: (v) => setState(() => _useSlider = v),
            onBindSideChanged: (v) => setState(() => _bindSide = v),
          ),
        ),
      ],
    );
  }

  Widget _buildPortrait() {
    final padding = MediaQuery.paddingOf(context);
    return _CompareStage(
      key: const Key('ba-compare-photo-stage'),
      left: _left,
      right: _right,
      useSlider: _useSlider,
      zoom: _zoom,
      onZoomIn: _zoomIn,
      onZoomOut: _zoomOut,
      topBar: Padding(
        padding: EdgeInsets.fromLTRB(8, padding.top + 4, 8, 0),
        child: _TopGlassBar(
          customerName: widget.customerName,
          programs: _programs,
          programKey: _programKey,
          left: _left,
          right: _right,
          slots: _scopedSlots,
          onProgramChanged: _selectProgram,
          onLeftChanged: _setLeft,
          onRightChanged: _setRight,
          onSwap: _swapSides,
        ),
      ),
      bottomBar: Padding(
        padding: EdgeInsets.fromLTRB(0, 0, 0, padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _BottomGlassBar(
                useSlider: _useSlider,
                onModeChanged: (v) => setState(() => _useSlider = v),
                left: _left,
                right: _right,
                bindSide: _bindSide,
                onBindSideChanged: (v) => setState(() => _bindSide = v),
              ),
            ),
            _storyStrip(),
          ],
        ),
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
    required this.zoom,
    required this.onZoomIn,
    required this.onZoomOut,
    this.topBar,
    this.bottomBar,
  });

  final VisitPhotoSlot? left;
  final VisitPhotoSlot? right;
  final bool useSlider;
  final double zoom;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final Widget? topBar;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: left != null && right != null
              ? _ComparePhotoBody(
                  left: left!,
                  right: right!,
                  useSlider: useSlider,
                  zoom: zoom,
                )
              : const ColoredBox(color: Color(0xFF0A0A0B)),
        ),
        Positioned(
          right: 8,
          top: 0,
          bottom: 0,
          child: Center(
            child: _ZoomStepper(
              zoom: zoom,
              onZoomIn: onZoomIn,
              onZoomOut: onZoomOut,
            ),
          ),
        ),
        if (topBar != null)
          Positioned(top: 0, left: 0, right: 0, child: topBar!),
        if (bottomBar != null)
          Positioned(bottom: 0, left: 0, right: 0, child: bottomBar!),
      ],
    );
  }
}

class _ComparePhotoBody extends StatelessWidget {
  const _ComparePhotoBody({
    required this.left,
    required this.right,
    required this.useSlider,
    required this.zoom,
  });

  final VisitPhotoSlot left;
  final VisitPhotoSlot right;
  final bool useSlider;
  final double zoom;

  Widget _pane(VisitPhotoSlot slot) {
    return ChartImagePane(
      url: slot.url,
      fallbackLabel: slot.shortLabel,
      tone: SoriTokens.textSecondary,
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final photo = useSlider
            ? BeforeAfterSlider(
                height: h,
                maxHeight: h,
                borderRadius: BorderRadius.zero,
                before: _pane(left),
                after: _pane(right),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _SidePane(label: left.label, child: _pane(left)),
                  ),
                  const ColoredBox(
                    color: Color(0xFF0A0A0B),
                    child: SizedBox(width: 2),
                  ),
                  Expanded(
                    child: _SidePane(label: right.label, child: _pane(right)),
                  ),
                ],
              );

        return ClipRect(
          child: AnimatedScale(
            scale: zoom,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: photo,
          ),
        );
      },
    );
  }
}

class _SidePane extends StatelessWidget {
  const _SidePane({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(left: 10, top: 10, child: _GlassChip(text: label)),
      ],
    );
  }
}

class _ZoomStepper extends StatelessWidget {
  const _ZoomStepper({
    required this.zoom,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final double zoom;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  String get _label {
    if (zoom == zoom.roundToDouble()) return '${zoom.toInt()}x';
    return '${zoom}x';
  }

  @override
  Widget build(BuildContext context) {
    final steps = BeforeAfterComparePage.zoomSteps;
    final atMin = zoom <= steps.first;
    final atMax = zoom >= steps.last;
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ZoomIconButton(
              key: const Key('ba-compare-zoom-in'),
              icon: Icons.add,
              tooltip: '확대',
              onPressed: atMax ? null : onZoomIn,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                _label,
                key: const Key('ba-compare-zoom-label'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _ZoomIconButton(
              key: const Key('ba-compare-zoom-out'),
              icon: Icons.remove,
              tooltip: '축소',
              onPressed: atMin ? null : onZoomOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomIconButton extends StatelessWidget {
  const _ZoomIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      color: Colors.white,
      disabledColor: Colors.white24,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
    required this.bindSide,
    required this.leftChart,
    required this.rightChart,
    required this.onProgramChanged,
    required this.onLeftChanged,
    required this.onRightChanged,
    required this.onSwap,
    required this.onModeChanged,
    required this.onBindSideChanged,
  });

  final String customerName;
  final List<CareProgramGroup> programs;
  final String programKey;
  final List<VisitPhotoSlot> slots;
  final VisitPhotoSlot? left;
  final VisitPhotoSlot? right;
  final bool useSlider;
  final BaCompareBindSide bindSide;
  final CustomerChart? leftChart;
  final CustomerChart? rightChart;
  final ValueChanged<String> onProgramChanged;
  final ValueChanged<VisitPhotoSlot> onLeftChanged;
  final ValueChanged<VisitPhotoSlot> onRightChanged;
  final VoidCallback onSwap;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<BaCompareBindSide> onBindSideChanged;

  @override
  Widget build(BuildContext context) {
    final focus = rightChart ?? leftChart;
    return ColoredBox(
      color: const Color(0xFF141416),
      child: SafeArea(
        left: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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
              items: [for (final p in programs) (value: p.key, label: p.label)],
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
            const SizedBox(height: 8),
            _BindSideToggle(bindSide: bindSide, onChanged: onBindSideChanged),
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
            if (focus != null && focus.treatmentSummary.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
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
            items: [for (final p in programs) (value: p.key, label: p.label)],
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
                    for (final s in slots) (value: s.key, label: s.shortLabel),
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
                    for (final s in slots) (value: s.key, label: s.shortLabel),
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
    required this.left,
    required this.right,
    required this.bindSide,
    required this.onBindSideChanged,
  });

  final bool useSlider;
  final ValueChanged<bool> onModeChanged;
  final VisitPhotoSlot? left;
  final VisitPhotoSlot? right;
  final BaCompareBindSide bindSide;
  final ValueChanged<BaCompareBindSide> onBindSideChanged;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeToggle(useSlider: useSlider, onChanged: onModeChanged),
          const SizedBox(height: 8),
          _BindSideToggle(bindSide: bindSide, onChanged: onBindSideChanged),
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
        ],
      ),
    );
  }
}

class _BindSideToggle extends StatelessWidget {
  const _BindSideToggle({required this.bindSide, required this.onChanged});

  final BaCompareBindSide bindSide;
  final ValueChanged<BaCompareBindSide> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '연결',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModeChip(
            key: const Key('ba-compare-bind-left'),
            label: '왼쪽',
            icon: Icons.chevron_left_rounded,
            selected: bindSide == BaCompareBindSide.left,
            onTap: () => onChanged(BaCompareBindSide.left),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _ModeChip(
            key: const Key('ba-compare-bind-right'),
            label: '오른쪽',
            icon: Icons.chevron_right_rounded,
            selected: bindSide == BaCompareBindSide.right,
            onTap: () => onChanged(BaCompareBindSide.right),
          ),
        ),
      ],
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
    super.key,
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
                    child: Text(item.label, overflow: TextOverflow.ellipsis),
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
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
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
