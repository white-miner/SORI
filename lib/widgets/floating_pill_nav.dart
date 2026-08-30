import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/sori_tokens.dart';
import 'glass/sori_glass_overlay.dart';
import 'glass/sori_glass_tokens.dart';

/// Weverse-style fluid drag bottom nav — glass white bar with blur.
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

  /// Glass white floating bar
  static Color get barBg => SoriTokens.glassFill;

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
        _highlightLeft = _spring.value;
        // 하이라이트만 리페인트 — 전체 setState 금지
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
    _highlightLeft = (localX - _highlightW / 2).clamp(minL, maxL);
    // AnimatedBuilder가 _spring 미사용 드래그도 반영하려면 setState 최소화:
    setState(() {});
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
            (Icons.photo_camera_outlined, Icons.photo_camera_rounded, '촬영', 2),
            (Icons.groups_outlined, Icons.groups_rounded, '커뮤니티', 3),
            (Icons.person_outline_rounded, Icons.person_rounded, '마이', 4),
          ]
        : const [
            (Icons.home_outlined, Icons.home_rounded, '홈', 0),
            (Icons.spa_outlined, Icons.spa_rounded, '케어', 1),
            (Icons.rate_review_outlined, Icons.rate_review_rounded, '리뷰', 2),
            (Icons.groups_outlined, Icons.groups_rounded, '커뮤니티', 3),
            (Icons.person_outline_rounded, Icons.person_rounded, '마이', 4),
          ];

    final labels = widget.isDirector
        ? [for (final e in items) e.$3]
        : [
            items[0].$3,
            items[1].$3,
            widget.reviewLabel.length > 4 ? '리뷰' : widget.reviewLabel,
            items[3].$3,
            items[4].$3,
          ];

    final visual = _visualIndex;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 12 + bottom,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _syncBarWidth(constraints.maxWidth);
          return SizedBox(
            height: _barH,
            child: SoriGlassOverlay(
              borderRadius: BorderRadius.circular(_radius),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  if (_laidOut && _highlightW > 0)
                    AnimatedBuilder(
                      animation: _spring,
                      builder: (context, _) {
                        final left = _dragging
                            ? _highlightLeft
                            : (_spring.isAnimating
                                ? _spring.value
                                : _highlightLeft);
                        return Positioned(
                          left: left,
                          top: _vInset,
                          bottom: _vInset,
                          width: _highlightW,
                          child: DecoratedBox(
                            decoration: SoriGlassTokens.pseudoChipDecoration(
                              radius: 24,
                              semantic: SoriGlassSemantic.neutral,
                              active: true,
                            ),
                          ),
                        );
                      },
                    ),
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
                                        ? SoriTokens.textCharcoal
                                        : SoriTokens.tabUnselected,
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
                                          ? SoriTokens.textCharcoal
                                          : SoriTokens.tabUnselected,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
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
