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

/// Creates [SoriFeedScrollPosition] so web pointerScroll can overshoot.
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

  double get _overshootMin => minScrollExtent - kSoriFeedMaxOvershoot;

  double get _overshootMax => maxScrollExtent + kSoriFeedMaxOvershoot;

  double _cap(double value) {
    if (!hasContentDimensions) return value;
    return value.clamp(_overshootMin, _overshootMax);
  }

  @override
  double setPixels(double newPixels) {
    return super.setPixels(_cap(newPixels));
  }

  @override
  void pointerScroll(double delta) {
    if (delta == 0.0) {
      goBallistic(0.0);
      return;
    }
    if (!hasPixels || !hasContentDimensions) return;

    final double target = _cap(pixels + delta);
    if (target == pixels) {
      goBallistic(0.0);
      return;
    }

    goIdle();
    updateUserScrollDirection(
      -delta > 0.0 ? ScrollDirection.forward : ScrollDirection.reverse,
    );
    final double oldPixels = pixels;
    isScrollingNotifier.value = true;
    forcePixels(target);
    didStartScroll();
    didUpdateScrollPositionBy(pixels - oldPixels);
    didEndScroll();
    goBallistic(0.0);
  }
}
