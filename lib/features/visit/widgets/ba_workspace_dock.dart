import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/sori_tokens.dart';
import '../../../views/before_after_compare_sheet.dart';
import '../../../widgets/before_after_slider.dart';
import 'ba_story_strip.dart';

/// 워크스페이스 슬롯 색. 세일즈 초록이 아니라 카메라 정렬 토큰이다.
abstract final class BaWorkspaceColors {
  static const Color before = SoriTokens.cameraYellow;
  static const Color after = SoriTokens.alignEmerald;
}

/// 하단 Before/After 웰 + 중앙 스냅 다이얼.
class BaWorkspaceDock extends StatelessWidget {
  const BaWorkspaceDock({
    super.key,
    required this.slots,
    required this.left,
    required this.right,
    required this.bindSide,
    required this.onBind,
    required this.onBindSide,
  });

  final List<VisitPhotoSlot> slots;
  final VisitPhotoSlot? left;
  final VisitPhotoSlot? right;
  final BaCompareBindSide bindSide;
  final ValueChanged<VisitPhotoSlot> onBind;
  final ValueChanged<BaCompareBindSide> onBindSide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          BaSlotWell(
            key: const Key('ba-well-before'),
            label: 'Before',
            slot: left,
            color: BaWorkspaceColors.before,
            active: bindSide == BaCompareBindSide.left,
            onTap: () => onBindSide(BaCompareBindSide.left),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: BaSnapDial(
              slots: slots,
              left: left,
              right: right,
              bindSide: bindSide,
              onBind: onBind,
            ),
          ),
          const SizedBox(width: 8),
          BaSlotWell(
            key: const Key('ba-well-after'),
            label: 'After',
            slot: right,
            color: BaWorkspaceColors.after,
            active: bindSide == BaCompareBindSide.right,
            onTap: () => onBindSide(BaCompareBindSide.right),
          ),
        ],
      ),
    );
  }
}

class BaSlotWell extends StatefulWidget {
  const BaSlotWell({
    super.key,
    required this.label,
    required this.slot,
    required this.color,
    required this.active,
    required this.onTap,
  });

  static const double size = 72;

  final String label;
  final VisitPhotoSlot? slot;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  State<BaSlotWell> createState() => _BaSlotWellState();
}

class _BaSlotWellState extends State<BaSlotWell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  @override
  void didUpdateWidget(BaSlotWell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.slot?.key != oldWidget.slot?.key && widget.active) {
      _pulse.forward(from: 0).then((_) {
        if (mounted) _pulse.reverse();
      });
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (widget.active) {
      await _pulse.forward(from: 0);
      await _pulse.reverse();
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final border = widget.active
        ? widget.color
        : Colors.white.withValues(alpha: 0.28);
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 1,
          end: 1.1,
        ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                color: widget.active
                    ? widget.color
                    : Colors.white.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: BaSlotWell.size,
              height: BaSlotWell.size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: border,
                  width: widget.active ? 3 : 1.5,
                ),
                color: const Color(0xFF1C1C1E),
              ),
              clipBehavior: Clip.antiAlias,
              child: widget.slot == null
                  ? const ColoredBox(color: Color(0xFF1C1C1E))
                  : ChartImagePane(
                      url: widget.slot!.url,
                      fallbackLabel: widget.slot!.storyLabel,
                      tone: SoriTokens.textSecondary,
                      fit: BoxFit.cover,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 중앙 아이템이 1.5배로 떠오르며 활성 슬롯에 스냅 바인딩되는 다이얼.
class BaSnapDial extends StatefulWidget {
  const BaSnapDial({
    super.key,
    required this.slots,
    required this.left,
    required this.right,
    required this.bindSide,
    required this.onBind,
  });

  static const double thumbSize = 56;
  static const double itemGap = 12;
  static const double stride = thumbSize + itemGap;
  static const double focusedScale = 1.5;
  static const double lift = 12;
  static const double height = 132;

  final List<VisitPhotoSlot> slots;
  final VisitPhotoSlot? left;
  final VisitPhotoSlot? right;
  final BaCompareBindSide bindSide;
  final ValueChanged<VisitPhotoSlot> onBind;

  @override
  State<BaSnapDial> createState() => _BaSnapDialState();
}

class _BaSnapDialState extends State<BaSnapDial> {
  final _scroll = ScrollController();
  int _centerIndex = 0;
  bool _ready = false;
  bool _suppressBind = false;

  VisitPhotoSlot? get _bound => widget.bindSide == BaCompareBindSide.left
      ? widget.left
      : widget.right;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _goTo(_indexOfBound(), animate: false, bind: false);
      _ready = true;
    });
  }

  @override
  void didUpdateWidget(BaSnapDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    final slotsChanged = oldWidget.slots.length != widget.slots.length ||
        !_sameKeys(oldWidget.slots, widget.slots);
    if (oldWidget.bindSide != widget.bindSide || slotsChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _goTo(_indexOfBound(), animate: !slotsChanged, bind: false);
      });
    }
  }

  bool _sameKeys(List<VisitPhotoSlot> a, List<VisitPhotoSlot> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].key != b[i].key) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  int _indexOfBound() {
    final key = _bound?.key;
    if (key == null) return 0;
    final i = widget.slots.indexWhere((s) => s.key == key);
    return i < 0 ? 0 : i;
  }

  int _indexFromOffset() {
    if (!_scroll.hasClients || widget.slots.isEmpty) return 0;
    final raw = (_scroll.offset / BaSnapDial.stride).round();
    return raw.clamp(0, widget.slots.length - 1);
  }

  void _onScroll() {
    if (_suppressBind || !_ready || widget.slots.isEmpty) return;
    final i = _indexFromOffset();
    if (i == _centerIndex) return;
    _centerIndex = i;
    HapticFeedback.selectionClick();
    widget.onBind(widget.slots[i]);
  }

  Future<void> _goTo(
    int index, {
    required bool animate,
    required bool bind,
  }) async {
    if (widget.slots.isEmpty) return;
    final i = index.clamp(0, widget.slots.length - 1);
    _suppressBind = true;
    _centerIndex = i;
    final target = i * BaSnapDial.stride;
    if (_scroll.hasClients) {
      final max = _scroll.position.maxScrollExtent;
      final pixels = target.clamp(0.0, max);
      if (animate) {
        await _scroll.animateTo(
          pixels,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scroll.jumpTo(pixels);
      }
    }
    if (!mounted) return;
    _suppressBind = false;
    if (bind) {
      HapticFeedback.selectionClick();
      widget.onBind(widget.slots[i]);
    }
  }

  void _step(int delta) {
    _goTo(_centerIndex + delta, animate: true, bind: true);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slots.isEmpty) {
      return const SizedBox(height: BaSnapDial.height);
    }
    return SizedBox(
      height: BaSnapDial.height,
      child: Row(
        children: [
          _Chevron(onTap: () => _step(-1), icon: Icons.chevron_left),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewport = constraints.maxWidth;
                final pad = ((viewport - BaSnapDial.stride) / 2).clamp(
                  0.0,
                  viewport,
                );
                return ListView.builder(
                  key: const Key('ba-story-strip-list'),
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  cacheExtent: widget.slots.length * BaSnapDial.stride + 240,
                  physics: const _SnapDialPhysics(itemExtent: BaSnapDial.stride),
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  itemExtent: BaSnapDial.stride,
                  itemCount: widget.slots.length,
                  itemBuilder: (context, index) {
                    return AnimatedBuilder(
                      animation: _scroll,
                      builder: (context, child) {
                        final offset = _scroll.hasClients ? _scroll.offset : 0.0;
                        final dist = (offset - index * BaSnapDial.stride).abs();
                        final t = (1 - dist / BaSnapDial.stride).clamp(0.0, 1.0);
                        final scale =
                            1 + (BaSnapDial.focusedScale - 1) * t;
                        return BaDialCell(
                          scale: scale,
                          lift: BaSnapDial.lift * t,
                          child: child!,
                        );
                      },
                      child: _dialThumb(index),
                    );
                  },
                );
              },
            ),
          ),
          _Chevron(onTap: () => _step(1), icon: Icons.chevron_right),
        ],
      ),
    );
  }

  Widget _dialThumb(int index) {
    final slot = widget.slots[index];
    final isBefore = widget.left?.key == slot.key;
    final isAfter = widget.right?.key == slot.key;
    final ring = isBefore
        ? BaWorkspaceColors.before
        : isAfter
        ? BaWorkspaceColors.after
        : Colors.white.withValues(alpha: 0.25);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onBind(slot);
        _goTo(index, animate: true, bind: false);
      },
      child: _FilmThumb(slot: slot, ring: ring, size: BaSnapDial.thumbSize),
    );
  }
}

class BaDialCell extends StatelessWidget {
  const BaDialCell({
    super.key,
    required this.scale,
    required this.lift,
    required this.child,
  });

  final double scale;
  final double lift;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, -lift),
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.bottomCenter,
        child: child,
      ),
    );
  }
}

class _FilmThumb extends StatelessWidget {
  const _FilmThumb({
    required this.slot,
    required this.ring,
    required this.size,
  });

  final VisitPhotoSlot slot;
  final Color ring;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: BaSnapDial.stride,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            key: Key('ba-story-thumb-${slot.key}'),
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ring, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: ChartImagePane(
              url: slot.url,
              fallbackLabel: slot.storyLabel,
              tone: SoriTokens.textSecondary,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            slot.storyLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.onTap, required this.icon});

  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 22, color: Colors.white),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }
}

class _SnapDialPhysics extends ScrollPhysics {
  const _SnapDialPhysics({super.parent, required this.itemExtent});

  final double itemExtent;

  @override
  _SnapDialPhysics applyTo(ScrollPhysics? ancestor) {
    return _SnapDialPhysics(
      parent: buildParent(ancestor),
      itemExtent: itemExtent,
    );
  }

  double _targetPixels(ScrollMetrics position, double velocity) {
    var page = position.pixels / itemExtent;
    if (velocity < -tolerance.velocity) {
      page -= 0.3;
    } else if (velocity > tolerance.velocity) {
      page += 0.3;
    }
    final maxPage = (position.maxScrollExtent / itemExtent);
    return page.roundToDouble().clamp(0, maxPage) * itemExtent;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final target = _targetPixels(position, velocity);
    if ((target - position.pixels).abs() < tolerance.distance &&
        velocity.abs() < tolerance.velocity) {
      return super.createBallisticSimulation(position, velocity);
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: toleranceFor(position),
    );
  }
}
