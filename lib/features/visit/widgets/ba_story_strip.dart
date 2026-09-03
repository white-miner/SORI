import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/sori_tokens.dart';
import '../../../views/before_after_compare_sheet.dart';
import '../../../widgets/before_after_slider.dart';

/// 스토리 스택이 메인 뷰어의 어느 슬롯에 사진을 넣을지.
enum BaCompareBindSide { left, right }

/// 인스타 스토리형 가로 썸네일 스택.
///
/// 아이템별 [AnimationController]를 두지 않는다. [hoverIndex]와
/// [AnimatedScale] 80ms 만으로 돋보기를 그린다.
class BaStoryStrip extends StatefulWidget {
  const BaStoryStrip({
    super.key,
    required this.slots,
    required this.left,
    required this.right,
    required this.bindSide,
    required this.onBind,
  });

  static const double thumbSize = 64;
  static const double thumbRadius = 18;
  static const double itemGap = 10;
  static const Duration popDuration = Duration(milliseconds: 80);
  static const double hoverScale = 1.38;
  static const double neighborScale = 1.12;

  final List<VisitPhotoSlot> slots;
  final VisitPhotoSlot? left;
  final VisitPhotoSlot? right;
  final BaCompareBindSide bindSide;
  final ValueChanged<VisitPhotoSlot> onBind;

  @override
  State<BaStoryStrip> createState() => _BaStoryStripState();
}

class _BaStoryStripState extends State<BaStoryStrip> {
  static const _listPadding = EdgeInsets.fromLTRB(16, 32, 16, 6);

  final _scroll = ScrollController();
  int? _hoverIndex;
  bool _magnifying = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  double get _itemExtent => BaStoryStrip.thumbSize + BaStoryStrip.itemGap;

  int? _indexAtGlobal(Offset global) {
    if (widget.slots.isEmpty) return null;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final local = box.globalToLocal(global);
    final dx =
        local.dx +
        (_scroll.hasClients ? _scroll.offset : 0) -
        _listPadding.left;
    if (dx < -BaStoryStrip.itemGap) return null;
    final index = (dx / _itemExtent).floor();
    if (index < 0 || index >= widget.slots.length) return null;
    return index;
  }

  void _setHover(int? index, {required bool haptic}) {
    if (index == _hoverIndex) return;
    setState(() => _hoverIndex = index);
    if (haptic && index != null) {
      HapticFeedback.lightImpact();
    }
  }

  void _bindIndex(int? index) {
    if (index == null || index < 0 || index >= widget.slots.length) return;
    widget.onBind(widget.slots[index]);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 124,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPressStart: (d) {
          final index = _indexAtGlobal(d.globalPosition);
          if (index == null) return;
          setState(() {
            _magnifying = true;
            _hoverIndex = index;
          });
          HapticFeedback.mediumImpact();
        },
        onLongPressMoveUpdate: (d) {
          if (!_magnifying) return;
          _setHover(_indexAtGlobal(d.globalPosition), haptic: true);
        },
        onLongPressEnd: (d) {
          final target = _hoverIndex ?? _indexAtGlobal(d.globalPosition);
          setState(() {
            _magnifying = false;
            _hoverIndex = null;
          });
          _bindIndex(target);
        },
        onLongPressCancel: () {
          setState(() {
            _magnifying = false;
            _hoverIndex = null;
          });
        },
        child: ListView.separated(
          key: const Key('ba-story-strip-list'),
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          physics: _magnifying
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          padding: _listPadding,
          itemCount: widget.slots.length,
          separatorBuilder: (_, _) =>
              const SizedBox(width: BaStoryStrip.itemGap),
          itemBuilder: (context, index) {
            final slot = widget.slots[index];
            final hover = _hoverIndex == index;
            final neighbor =
                _hoverIndex != null && (_hoverIndex! - index).abs() == 1;
            final scale = hover
                ? BaStoryStrip.hoverScale
                : neighbor
                ? BaStoryStrip.neighborScale
                : 1.0;
            return _StoryThumb(
              slot: slot,
              isLeft: widget.left?.key == slot.key,
              isRight: widget.right?.key == slot.key,
              bindSide: widget.bindSide,
              scale: scale,
              lift: hover,
              onTap: () => widget.onBind(slot),
            );
          },
        ),
      ),
    );
  }
}

class _StoryThumb extends StatelessWidget {
  const _StoryThumb({
    required this.slot,
    required this.isLeft,
    required this.isRight,
    required this.bindSide,
    required this.scale,
    required this.lift,
    required this.onTap,
  });

  final VisitPhotoSlot slot;
  final bool isLeft;
  final bool isRight;
  final BaCompareBindSide bindSide;
  final double scale;
  final bool lift;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = isLeft || isRight;
    final ring = selected ? Colors.white : Colors.white.withValues(alpha: 0.28);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: BaStoryStrip.thumbSize,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSlide(
              offset: Offset(0, lift ? -0.22 : 0),
              duration: BaStoryStrip.popDuration,
              curve: Curves.easeOut,
              child: AnimatedScale(
                scale: scale,
                duration: BaStoryStrip.popDuration,
                curve: Curves.easeOut,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      key: Key('ba-story-thumb-${slot.key}'),
                      width: BaStoryStrip.thumbSize,
                      height: BaStoryStrip.thumbSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          BaStoryStrip.thumbRadius,
                        ),
                        border: Border.all(
                          color: ring,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ChartImagePane(
                        url: slot.url,
                        fallbackLabel: slot.storyLabel,
                        tone: SoriTokens.textSecondary,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (isLeft || isRight)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: _SideBadge(
                          text: isLeft && isRight
                              ? 'L/R'
                              : isLeft
                              ? 'L'
                              : 'R',
                          emphasized:
                              (isLeft && bindSide == BaCompareBindSide.left) ||
                              (isRight && bindSide == BaCompareBindSide.right),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              slot.storyLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.78),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideBadge extends StatelessWidget {
  const _SideBadge({required this.text, required this.emphasized});

  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: emphasized ? Colors.white : const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: emphasized ? SoriTokens.textPrimary : Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
