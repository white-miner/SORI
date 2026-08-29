import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Provides the active feed [ScrollController] to margin / gap wheel forwarders.
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

/// PC side-margin zone — Instagram / YouTube style wheel on empty gutters.
class FeedMarginWheelZone extends StatelessWidget {
  const FeedMarginWheelZone({super.key});

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        FeedWheelForwarder.forward(context, event);
      },
      child: const ColoredBox(
        color: Colors.transparent,
        child: SizedBox.expand(),
      ),
    );
  }
}

/// Central feed column — fills the 720px viewport (native wheel on scroll view).
class FeedScrollColumn extends StatelessWidget {
  const FeedScrollColumn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: child,
        );
      },
    );
  }
}

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

/// @deprecated Use [FeedMarginWheelZone] + [FeedWheelForwarder].
class MarginScrollForwarder extends StatelessWidget {
  const MarginScrollForwarder({super.key, this.child});

  final Widget? child;

  static void forwardWheel(BuildContext context, PointerScrollEvent event) {
    FeedWheelForwarder.forward(context, event);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        FeedWheelForwarder.forward(context, event);
      },
      child: child ?? const SizedBox.expand(),
    );
  }
}
