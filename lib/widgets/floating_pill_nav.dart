import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/sori_tokens.dart';

/// Weverse-style fluid drag bottom nav with glassmorphism highlight.
class FloatingPillNav extends StatefulWidget {
  const FloatingPillNav({
    super.key,
    required this.currentIndex,
    required this.isDirector,
    required this.reviewLabel,
    required this.onTap,
  });

  final int currentIndex;
  final bool isDirector;
  final String reviewLabel;
  final ValueChanged<int> onTap;

  /// #121214 @ 90%
  static const Color barBg = Color(0xE6121214);

  @override
  State<FloatingPillNav> createState() => _FloatingPillNavState();
}

class _FloatingPillNavState extends State<FloatingPillNav>
    with SingleTickerProviderStateMixin {
  static const int _count = 5;
  static const double _barH = 64;
  static const double _radius = 32;
  static const double _hInset = 6;
  static const double _vInset = 6;

  late final AnimationController _spring;
  double _barWidth = 0;
  double _highlightLeft = 0;
  bool _laidOut = false;
  bool _dragging = false;

  double get _slotW =>
      _barWidth <= 0 ? 0 : (_barWidth - _hInset * 2) / _count;

  double get _highlightW => _slotW <= 0 ? 0 : (_slotW - 4).clamp(36.0, 120.0);

  double _leftForIndex(int index) {
    final i = index.clamp(0, _count - 1);
    return _hInset + i * _slotW + (_slotW - _highlightW) / 2;
  }

  int _indexFromCenterX(double centerX) {
    if (_slotW <= 0) return widget.currentIndex;
    final raw = ((centerX - _hInset) / _slotW).floor();
    return raw.clamp(0, _count - 1);
  }

  int get _visualIndex {
    if (!_laidOut) return widget.currentIndex;
    return _indexFromCenterX(_highlightLeft + _highlightW / 2);
  }

  @override
  void initState() {
    super.initState();
    _spring = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        setState(() => _highlightLeft = _spring.value);
      });
  }

  @override
  void didUpdateWidget(covariant FloatingPillNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging &&
        oldWidget.currentIndex != widget.currentIndex &&
        _laidOut) {
      _animateToIndex(widget.currentIndex, notify: false);
    }
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  void _animateToIndex(int index, {bool notify = true, double velocity = 0}) {
    if (!_laidOut) {
      if (notify) widget.onTap(index);
      return;
    }
    final target = _leftForIndex(index);
    _spring.stop();
    final sim = SpringSimulation(
      const SpringDescription(mass: 0.85, stiffness: 220, damping: 18),
      _highlightLeft,
      target,
      velocity,
    );
    if (notify) widget.onTap(index);
    _spring.animateWith(sim).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _dragging = false;
        _highlightLeft = _leftForIndex(index);
      });
    });
  }

  void _syncBarWidth(double width) {
    if (width <= 0) return;
    final first = !_laidOut;
    final resized = (width - _barWidth).abs() > 0.5;
    if (!first && !resized) return;
    _barWidth = width;
    _laidOut = true;
    if (!_dragging) {
      _highlightLeft = _leftForIndex(widget.currentIndex);
    }
  }

  void _moveHighlightToLocalX(double localX) {
    if (_highlightW <= 0) return;
    final minL = _hInset;
    final maxL = _barWidth - _hInset - _highlightW;
    setState(() {
      _highlightLeft = (localX - _highlightW / 2).clamp(minL, maxL);
    });
  }

  void _onTapUp(TapUpDetails details) {
    final index = _indexFromCenterX(details.localPosition.dx);
    _dragging = false;
    _animateToIndex(index);
  }

  void _onDragStart(DragStartDetails details) {
    _spring.stop();
    _dragging = true;
    _moveHighlightToLocalX(details.localPosition.dx);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragging = true;
    _moveHighlightToLocalX(details.localPosition.dx);
  }

  void _onDragEnd(DragEndDetails details) {
    final index = _indexFromCenterX(_highlightLeft + _highlightW / 2);
    final vx = details.velocity.pixelsPerSecond.dx;
    _animateToIndex(index, velocity: vx * 0.15);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final items = widget.isDirector
        ? const [
            (Icons.home_outlined, Icons.home_rounded, '홈', 0),
            (Icons.people_outline, Icons.people_rounded, '고객', 1),
            (Icons.rate_review_outlined, Icons.rate_review_rounded, '리뷰', 2),
            (Icons.photo_library_outlined, Icons.photo_library_rounded, '케이스', 3),
            (Icons.person_outline_rounded, Icons.person_rounded, '마이', 4),
          ]
        : const [
            (Icons.home_outlined, Icons.home_rounded, '홈', 0),
            (Icons.spa_outlined, Icons.spa_rounded, '케어', 1),
            (Icons.rate_review_outlined, Icons.rate_review_rounded, '리뷰', 2),
            (Icons.photo_library_outlined, Icons.photo_library_rounded, '케이스', 3),
            (Icons.person_outline_rounded, Icons.person_rounded, '마이', 4),
          ];

    final labels = [
      items[0].$3,
      items[1].$3,
      widget.reviewLabel.length > 4 ? '리뷰' : widget.reviewLabel,
      items[3].$3,
      items[4].$3,
    ];

    final visual = _visualIndex;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: 24 + bottom,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _syncBarWidth(constraints.maxWidth);
          return Container(
            height: _barH,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_radius),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // Layer 1 — dark capsule background
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: FloatingPillNav.barBg,
                          borderRadius: BorderRadius.circular(_radius),
                          border: Border.all(
                            color: SoriTokens.outlinePurple,
                            width: SoriTokens.outlineWidth,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Layer 2 — fluid glass highlight
                  if (_laidOut && _highlightW > 0)
                    Positioned(
                      left: _highlightLeft,
                      top: _vInset,
                      bottom: _vInset,
                      width: _highlightW,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: SoriTokens.outlinePurple,
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: SoriTokens.primary
                                      .withValues(alpha: 0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Layer 3 — icons + labels
                  Positioned.fill(
                    child: Row(
                      children: List.generate(_count, (i) {
                        final selected = visual == i;
                        return Expanded(
                          child: IgnorePointer(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  selected ? items[i].$2 : items[i].$1,
                                  size: 22,
                                  color: selected
                                      ? SoriTokens.primary
                                      : SoriTokens.textSecondary,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  labels[i],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: selected
                                        ? SoriTokens.primary
                                        : SoriTokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Gesture layer — tap + horizontal fluid drag
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: _onTapUp,
                      onHorizontalDragStart: _onDragStart,
                      onHorizontalDragUpdate: _onDragUpdate,
                      onHorizontalDragEnd: _onDragEnd,
                      onHorizontalDragCancel: () {
                        _animateToIndex(_visualIndex);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
