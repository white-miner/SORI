import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';

/// Top-stage text tabs — Weverse-style left-aligned labels + charcoal underline.
///
/// Indicator API (ready for real signals only — do not fake):
/// * [dotIndex] — green live/progress dot (e.g. FLOW care timer).
/// * [badges] — red unread/new count pills per tab (0/null = hidden). Cap `99+`.
/// Community 추천/탐색 currently have no unread SSOT; leave [badges] null until
/// a real source exists. Director hub already wires review badges.
class SoriStageFolderTabs extends StatefulWidget {
  const SoriStageFolderTabs({
    super.key,
    required this.controller,
    required this.labels,
    this.minWidths,
    this.dotIndex,
    this.badges,
    this.allowScroll = false,
  });

  final TabController controller;

  /// Left-to-right labels; length must match [controller.length].
  final List<String> labels;

  /// Optional per-label minimum widths so press/select does not jitter layout.
  final List<double>? minWidths;

  /// Green live/progress dot on this index (e.g. running FLOW timer). Null = none.
  final int? dotIndex;

  /// Optional per-tab badge counts (0 / null entry = hidden). Red count pills.
  final List<int>? badges;

  /// When true and labels overflow, scroll horizontally instead of shrinking
  /// (My page 6 tabs). Keeps left-align + label-width underline.
  final bool allowScroll;

  static const double railHeight = 48;

  /// Top breathing room between logo app-bar row and tab rail.
  static const double topInset = 0;

  /// Total chrome height when [topInset] is applied (e.g. PreferredSize).
  static const double chromeHeight = railHeight + topInset;

  static const double _unselectedHeight = 48;
  static const double _selectedHeight = 48;

  /// Left inset; right side stays open for breathing room (not equal-fit).
  static const double _sidePad = 16;
  static const double _hPad = 10;

  /// Gap between intrinsic tabs — Weverse-style breathing, not equal slots.
  static const double _gap = 18;

  static const _unselectedText = Color(0xFF6E6E73);
  static const _selectedText = SoriTokens.textCharcoal;
  static const _hairline = Colors.transparent;

  /// Labels that get a very light personality tweak (community 우리지역 only).
  static const _personalityLabels = {'우리지역'};

  static const _unselectedStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: _unselectedText,
    height: 1.2,
    letterSpacing: 0.15,
  );
  static const _selectedStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: _selectedText,
    height: 1.2,
    letterSpacing: 0.1,
  );

  static final _allCaps = RegExp(r'^[A-Z][A-Z0-9 &/+.-]*$');

  /// Soften pressure; ALL-CAPS visit labels ease tracking without changing keys.
  static TextStyle _styleFor(String label, {required bool selected}) {
    final base = selected ? _selectedStyle : _unselectedStyle;
    if (_personalityLabels.contains(label)) {
      return base.copyWith(
        letterSpacing: selected ? 0.05 : 0.12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
      );
    }
    if (_allCaps.hasMatch(label)) {
      return base.copyWith(
        letterSpacing: selected ? 0.4 : 0.55,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 14,
      );
    }
    return base;
  }

  @override
  State<SoriStageFolderTabs> createState() => _SoriStageFolderTabsState();
}

class _SoriStageFolderTabsState extends State<SoriStageFolderTabs> {
  int? _pressedIndex;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant SoriStageFolderTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final n = labels.length;
    final selectedIndex = widget.controller.index;
    final scaler = MediaQuery.textScalerOf(context);

    final textWidths = [
      for (var i = 0; i < n; i++) _labelTextWidth(labels[i], scaler),
    ];
    final contentWidths = [
      for (var i = 0; i < n; i++) _contentWidth(textWidths[i], i),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewW = MediaQuery.sizeOf(context).width;
        final raw = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : viewW;
        final maxWidth = raw < viewW ? raw : viewW;
        final layout = _tabWidths(contentWidths, maxWidth);
        final widths = layout.widths;
        final gap = layout.gap;

        final lefts = <double>[];
        var cursor = SoriStageFolderTabs._sidePad;
        for (final w in widths) {
          lefts.add(cursor);
          cursor += w + gap;
        }

        final children = <Widget>[
          const Positioned(
            key: Key('sori-stage-tabs-hairline'),
            left: 0,
            right: 0,
            bottom: 0,
            height: 1,
            child: ColoredBox(color: SoriStageFolderTabs._hairline),
          ),
        ];

        for (var i = 0; i < n; i++) {
          if (i == selectedIndex) continue;
          children.add(
            _tab(
              index: i,
              left: lefts[i],
              width: widths[i],
              underlineWidth: textWidths[i],
              selected: false,
            ),
          );
        }

        children.add(
          _tab(
            index: selectedIndex,
            left: lefts[selectedIndex],
            width: widths[selectedIndex],
            underlineWidth: textWidths[selectedIndex],
            selected: true,
          ),
        );

        final contentSpan = SoriStageFolderTabs._sidePad * 2 +
            widths.fold<double>(0, (a, b) => a + b) +
            gap * (n - 1);
        final needsScroll =
            widget.allowScroll && contentSpan > maxWidth + 0.5;
        final rail = SizedBox(
          width: needsScroll ? contentSpan : double.infinity,
          height: SoriStageFolderTabs.railHeight,
          child: Stack(clipBehavior: Clip.none, children: children),
        );
        return ColoredBox(
          color: SoriTokens.canvas,
          child: needsScroll
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: rail,
                )
              : rail,
        );
      },
    );
  }

  Widget _tab({
    required int index,
    required double left,
    required double width,
    required double underlineWidth,
    required bool selected,
  }) {
    final height = selected
        ? SoriStageFolderTabs._selectedHeight
        : SoriStageFolderTabs._unselectedHeight;
    final bottom = selected ? 0.0 : 1.0;
    final pressed = _pressedIndex == index;
    final label = widget.labels[index];
    final style = SoriStageFolderTabs._styleFor(label, selected: selected);

    return Positioned(
      key: Key('sori-stage-tab-$index'),
      left: left,
      bottom: bottom,
      width: width,
      height: height,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressedIndex = index),
          onTapUp: (_) => setState(() => _pressedIndex = null),
          onTapCancel: () => setState(() => _pressedIndex = null),
          onTap: () {
            if (widget.controller.index != index) {
              widget.controller.index = index;
            }
          },
          child: KeyedSubtree(
            key: selected
                ? const Key('home-filed-label')
                : Key('sori-stage-tab-unfiled-$index'),
            child: AnimatedContainer(
              key: Key('sori-stage-tab-fill-$index'),
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: width,
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: pressed
                    ? SoriTokens.textCharcoal.withValues(alpha: 0.04)
                    : Colors.transparent,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: style,
                        ),
                      ),
                      if (widget.dotIndex == index) ...[
                        const SizedBox(width: 5),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: SoriTokens.semanticGreen,
                          ),
                        ),
                      ],
                      if (_badgeCount(index) > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: SoriTokens.systemRed,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            _badgeCount(index) > 99
                                ? '99+'
                                : '${_badgeCount(index)}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: SoriTokens.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    key: Key('sori-stage-tab-underline-$index'),
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    width: selected ? underlineWidth : 0,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: selected
                          ? SoriTokens.textCharcoal
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Pure label glyph width (underline target) — excludes dots/badges.
  double _labelTextWidth(String label, TextScaler scaler) {
    final style = SoriStageFolderTabs._styleFor(label, selected: true);
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    return painter.size.width;
  }

  /// Tab slot content width: label + optional dot/badge + horizontal pad.
  double _contentWidth(double textWidth, int index) {
    var width = textWidth;
    if (widget.dotIndex == index) width += 11;
    final badge = _badgeCount(index);
    if (badge > 0) {
      final digits = badge > 99 ? 3 : '$badge'.length;
      width += 5 + 12 + digits * 6.0;
    }
    width += SoriStageFolderTabs._hPad * 2;
    final minWidths = widget.minWidths;
    if (minWidths != null && index < minWidths.length) {
      width = _max(width, minWidths[index]);
    }
    return width;
  }

  /// Intrinsic left-aligned widths. Grow is NOT distributed across the viewport.
  /// Only shrink (and tighten gap) when content would overflow.
  ({List<double> widths, double gap}) _tabWidths(
    List<double> contentMins,
    double maxWidth,
  ) {
    final n = contentMins.length;
    var gap = SoriStageFolderTabs._gap;

    double spanFor(double g) =>
        maxWidth - SoriStageFolderTabs._sidePad * 2 - g * (n - 1);

    var available = spanFor(gap);
    final minSum = contentMins.fold<double>(0, (a, b) => a + b);

    while (available < minSum && gap > 6) {
      gap -= 1;
      available = spanFor(gap);
    }

    final widths = List<double>.from(contentMins);
    final canScroll = widget.allowScroll;
    if (!canScroll && minSum > available && minSum > 0) {
      final scale = available / minSum;
      for (var i = 0; i < n; i++) {
        widths[i] = contentMins[i] * scale;
      }
    }
    // else: keep intrinsic widths — left-aligned, right breathing room
    // (or horizontal scroll when [allowScroll]).

    return (widths: widths, gap: gap);
  }

  int _badgeCount(int index) {
    final badges = widget.badges;
    if (badges == null || index >= badges.length) return 0;
    return badges[index];
  }

  static double _max(double a, double b) => a > b ? a : b;
}
