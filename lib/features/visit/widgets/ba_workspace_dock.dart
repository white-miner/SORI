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

/// 하단 Before/After 웰 + 필름. 활성 슬롯으로 자석 바인딩한다.
class BaWorkspaceDock extends StatelessWidget {
  const BaWorkspaceDock({
    super.key,
    required this.slots,
    required this.left,
    required this.right,
    required this.bindSide,
    required this.onBind,
    required this.onBindSide,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  final List<VisitPhotoSlot> slots;
  final VisitPhotoSlot? left;
  final VisitPhotoSlot? right;
  final BaCompareBindSide bindSide;
  final ValueChanged<VisitPhotoSlot> onBind;
  final ValueChanged<BaCompareBindSide> onBindSide;
  final ValueChanged<VisitPhotoSlot> onDragStarted;
  final VoidCallback onDragEnded;

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
            onAccept: (s) {
              onBindSide(BaCompareBindSide.left);
              onBind(s);
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilmStrip(
              slots: slots,
              left: left,
              right: right,
              onBind: onBind,
              onDragStarted: onDragStarted,
              onDragEnded: onDragEnded,
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
            onAccept: (s) {
              onBindSide(BaCompareBindSide.right);
              onBind(s);
            },
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
    required this.onAccept,
  });

  static const double size = 72;

  final String label;
  final VisitPhotoSlot? slot;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  final ValueChanged<VisitPhotoSlot> onAccept;

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
    return DragTarget<VisitPhotoSlot>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) {
        HapticFeedback.lightImpact();
        widget.onAccept(d.data);
      },
      builder: (context, candidate, _) {
        final hovering = candidate.isNotEmpty;
        return GestureDetector(
          onTap: _handleTap,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 1,
              end: 1.1,
            ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut)),
            child: AnimatedScale(
              scale: hovering ? 1.08 : 1,
              duration: const Duration(milliseconds: 80),
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
                        color: hovering ? widget.color : border,
                        width: widget.active || hovering ? 3 : 1.5,
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
          ),
        );
      },
    );
  }
}

class _FilmStrip extends StatefulWidget {
  const _FilmStrip({
    required this.slots,
    required this.left,
    required this.right,
    required this.onBind,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  final List<VisitPhotoSlot> slots;
  final VisitPhotoSlot? left;
  final VisitPhotoSlot? right;
  final ValueChanged<VisitPhotoSlot> onBind;
  final ValueChanged<VisitPhotoSlot> onDragStarted;
  final VoidCallback onDragEnded;

  @override
  State<_FilmStrip> createState() => _FilmStripState();
}

class _FilmStripState extends State<_FilmStrip> {
  final _scroll = ScrollController();

  static const _thumb = 56.0;
  static const _gap = 8.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _nudge(double delta) {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      (_scroll.offset + delta).clamp(0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: Row(
        children: [
          _Chevron(onTap: () => _nudge(-120), icon: Icons.chevron_left),
          Expanded(
            child: ListView.separated(
              key: const Key('ba-story-strip-list'),
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              itemCount: widget.slots.length,
              separatorBuilder: (_, _) => const SizedBox(width: _gap),
              itemBuilder: (context, index) {
                final slot = widget.slots[index];
                final isBefore = widget.left?.key == slot.key;
                final isAfter = widget.right?.key == slot.key;
                final ring = isBefore
                    ? BaWorkspaceColors.before
                    : isAfter
                    ? BaWorkspaceColors.after
                    : Colors.white.withValues(alpha: 0.25);
                return LongPressDraggable<VisitPhotoSlot>(
                  data: slot,
                  hapticFeedbackOnStart: true,
                  onDragStarted: () => widget.onDragStarted(slot),
                  onDragEnd: (_) => widget.onDragEnded(),
                  onDraggableCanceled: (_, _) => widget.onDragEnded(),
                  feedback: Material(
                    color: Colors.transparent,
                    child: Transform.scale(
                      scale: 1.35,
                      child: _FilmThumb(slot: slot, ring: ring, size: _thumb),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.35,
                    child: _FilmThumb(slot: slot, ring: ring, size: _thumb),
                  ),
                  child: GestureDetector(
                    onTap: () => widget.onBind(slot),
                    child: _FilmThumb(slot: slot, ring: ring, size: _thumb),
                  ),
                );
              },
            ),
          ),
          _Chevron(onTap: () => _nudge(120), icon: Icons.chevron_right),
        ],
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
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
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

/// 드래그 중 화면 중앙 자석 프리뷰.
class BaMagnetPreview extends StatelessWidget {
  const BaMagnetPreview({
    super.key,
    required this.slot,
    required this.bindSide,
  });

  final VisitPhotoSlot slot;
  final BaCompareBindSide bindSide;

  @override
  Widget build(BuildContext context) {
    final color = bindSide == BaCompareBindSide.left
        ? BaWorkspaceColors.before
        : BaWorkspaceColors.after;
    return DragTarget<VisitPhotoSlot>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (_) {},
      builder: (context, candidate, _) {
        return IgnorePointer(
          child: Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color, width: 3),
              color: const Color(0xFF1C1C1E),
            ),
            clipBehavior: Clip.antiAlias,
            child: ChartImagePane(
              url: slot.url,
              fallbackLabel: slot.storyLabel,
              tone: SoriTokens.textSecondary,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }
}
