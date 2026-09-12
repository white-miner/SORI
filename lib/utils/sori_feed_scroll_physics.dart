import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../widgets/app_scroll_behavior.dart';

/// Feed-only overscroll. Do not apply through global [SoriScrollBehavior]
/// or to Timer / Visit / Consent / sheets / map / camera.
const ScrollPhysics soriFeedScrollPhysics = BouncingScrollPhysics(
  parent: AlwaysScrollableScrollPhysics(),
);

/// Max pixels past min/max extent on feed surfaces.
const double kSoriFeedMaxOvershoot = 80;

/// After the last feed pointer-scroll event, wait this long then ballistically
/// return to extent. Immediate [goBallistic] on every event hides the bounce.
const Duration kSoriFeedPointerSettle = Duration(milliseconds: 80);

/// Feed-local behavior: bounce physics, no stretch/glow, same drag devices.
class SoriFeedScrollBehavior extends SoriScrollBehavior {
  const SoriFeedScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => soriFeedScrollPhysics;

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

/// Wraps a feed [ScrollView] with [SoriFeedScrollBehavior] and the pointer
/// path that bypasses [Scrollable]'s hard [minScrollExtent]/[maxScrollExtent]
/// clamp (that clamp is why [SoriFeedScrollPosition.pointerScroll] alone
/// never ran on real mobile-web).
class SoriFeedScrollSurface extends StatelessWidget {
  const SoriFeedScrollSurface({
    super.key,
    this.controller,
    required this.child,
  });

  final ScrollController? controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const SoriFeedScrollBehavior(),
      child: Listener(
        onPointerSignal: (PointerSignalEvent event) {
          applySoriFeedPointerSignal(event, controller);
        },
        child: child,
      ),
    );
  }
}

/// When [Scrollable] would ignore a wheel/pointer tick because the clamped
/// target equals [ScrollPosition.pixels], forward it to the feed position.
void applySoriFeedPointerSignal(
  PointerSignalEvent event,
  ScrollController? controller,
) {
  if (event is! PointerScrollEvent) return;
  if (controller == null || !controller.hasClients) return;
  final ScrollPosition pos = controller.position;
  if (pos is! SoriFeedScrollPosition) return;
  if (!pos.hasPixels || !pos.hasContentDimensions) return;

  final double delta = event.scrollDelta.dy;
  if (delta == 0.0) return;

  final double clamped = clampDouble(
    pos.pixels + delta,
    pos.minScrollExtent,
    pos.maxScrollExtent,
  );
  if (clamped != pos.pixels) return;

  GestureBinding.instance.pointerSignalResolver.register(event, (
    PointerEvent resolved,
  ) {
    if (resolved is! PointerScrollEvent) return;
    pos.pointerScroll(resolved.scrollDelta.dy);
    resolved.respond(allowPlatformDefault: false);
  });
}

/// Creates [SoriFeedScrollPosition] so feed pointerScroll can overshoot.
class SoriFeedScrollController extends ScrollController {
  SoriFeedScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
    super.onAttach,
    super.onDetach,
  });

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return SoriFeedScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

/// Caps overshoot at [kSoriFeedMaxOvershoot] and lets pointerScroll leave
/// the [minScrollExtent, maxScrollExtent] clamp used by default positions.
class SoriFeedScrollPosition extends ScrollPositionWithSingleContext {
  SoriFeedScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  Timer? _pointerSettle;

  double get _overshootMin => minScrollExtent - kSoriFeedMaxOvershoot;

  double get _overshootMax => maxScrollExtent + kSoriFeedMaxOvershoot;

  double _cap(double value) {
    if (!hasContentDimensions) return value;
    return clampDouble(value, _overshootMin, _overshootMax);
  }

  void _cancelPointerSettle() {
    _pointerSettle?.cancel();
    _pointerSettle = null;
  }

  void _schedulePointerSettle() {
    _cancelPointerSettle();
    _pointerSettle = Timer(kSoriFeedPointerSettle, () {
      _pointerSettle = null;
      if (hasPixels) {
        goBallistic(0.0);
      }
    });
  }

  @override
  double setPixels(double newPixels) {
    return super.setPixels(_cap(newPixels));
  }

  @override
  void pointerScroll(double delta) {
    if (delta == 0.0) {
      _cancelPointerSettle();
      goBallistic(0.0);
      return;
    }
    if (!hasPixels || !hasContentDimensions) return;

    final double target = _cap(pixels + delta);
    goIdle();
    updateUserScrollDirection(
      -delta > 0.0 ? ScrollDirection.forward : ScrollDirection.reverse,
    );
    if (target != pixels) {
      final double oldPixels = pixels;
      isScrollingNotifier.value = true;
      forcePixels(target);
      didStartScroll();
      didUpdateScrollPositionBy(pixels - oldPixels);
      didEndScroll();
    }
    _schedulePointerSettle();
  }

  @override
  void dispose() {
    _cancelPointerSettle();
    super.dispose();
  }
}
