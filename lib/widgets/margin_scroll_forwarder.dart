import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Provides the active feed [ScrollController] to margin wheel forwarders.
class FeedScrollScope extends InheritedWidget {
  const FeedScrollScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final ScrollController controller;

  static ScrollController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<FeedScrollScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(FeedScrollScope oldWidget) {
    return oldWidget.controller != controller;
  }
}

/// Forwards wheel / trackpad scroll to the feed [ScrollController].
class FeedWheelForwarder {
  FeedWheelForwarder._();

  static void forward(BuildContext context, PointerScrollEvent event) {
    final delta = -event.scrollDelta.dy;
    if (delta == 0) return;

    final controller =
        FeedScrollScope.maybeOf(context) ??
        PrimaryScrollController.maybeOf(context);
    if (controller == null || !controller.hasClients) return;

    final pos = controller.position;
    if (!pos.hasContentDimensions) return;
    pos.pointerScroll(delta);
  }
}

/// **Margin (여백)** = the entire wheel-scroll capture zone for the home feed:
/// (1) empty background inside the central feed column (beside / between cards),
/// (2) empty space to the left of that column (sidebar ↔ feed),
/// (3) empty space to the right (feed ↔ right sidebar).
///
/// Wrap once around the combined region. [Listener] receives wheel events from
/// this widget and all descendants (Instagram / YouTube PC style).
class FeedWheelMarginSurface extends StatelessWidget {
  const FeedWheelMarginSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        FeedWheelForwarder.forward(context, event);
      },
      child: child,
    );
  }
}

/// @deprecated Use [FeedWheelMarginSurface].
typedef FeedMarginWheelZone = FeedWheelMarginSurface;

/// @deprecated Use [FeedWheelMarginSurface].
typedef FeedScrollColumn = FeedWheelMarginSurface;

/// Full-width wrapper for feed list rows (card side gaps scroll too).
class FeedScrollRow extends StatelessWidget {
  const FeedScrollRow({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.transparent,
      child: SizedBox(
        width: double.infinity,
        child: child,
      ),
    );
  }
}

/// @deprecated Use [FeedWheelMarginSurface].
class MarginScrollForwarder extends StatelessWidget {
  const MarginScrollForwarder({super.key, this.child});

  final Widget? child;

  static void forwardWheel(BuildContext context, PointerScrollEvent event) {
    FeedWheelForwarder.forward(context, event);
  }

  @override
  Widget build(BuildContext context) {
    return FeedWheelMarginSurface(
      child: child ?? const SizedBox.expand(),
    );
  }
}
