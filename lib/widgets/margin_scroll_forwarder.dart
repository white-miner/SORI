import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Global handle for the active home-feed scroll position (web-safe).
class FeedScrollBridge {
  FeedScrollBridge._();

  static ScrollController? _controller;

  static ScrollController? get controller => _controller;

  static void bind(ScrollController? controller) {
    _controller = controller;
  }

  /// Returns true when scroll was applied.
  static bool scrollBy(double delta) {
    if (delta == 0) return false;

    final controller = _controller;
    if (controller != null && controller.hasClients) {
      for (final pos in controller.positions) {
        if (!pos.hasContentDimensions) continue;
        pos.pointerScroll(delta);
        return true;
      }
    }
    return false;
  }
}

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

/// Binds [controller] while mounted — used by the shell and feed page.
class FeedScrollScopeBinder extends StatefulWidget {
  const FeedScrollScopeBinder({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  State<FeedScrollScopeBinder> createState() => _FeedScrollScopeBinderState();
}

class _FeedScrollScopeBinderState extends State<FeedScrollScopeBinder> {
  @override
  void initState() {
    super.initState();
    FeedScrollBridge.bind(widget.controller);
  }

  @override
  void didUpdateWidget(FeedScrollScopeBinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      FeedScrollBridge.bind(widget.controller);
    }
  }

  @override
  void dispose() {
    if (FeedScrollBridge.controller == widget.controller) {
      FeedScrollBridge.bind(null);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FeedScrollScope(
      controller: widget.controller,
      child: widget.child,
    );
  }
}

/// Forwards wheel / trackpad scroll to the feed [ScrollController].
class FeedWheelForwarder {
  FeedWheelForwarder._();

  static void forward(BuildContext context, PointerScrollEvent event) {
    final delta = -event.scrollDelta.dy;
    if (delta == 0) return;

    if (FeedScrollBridge.scrollBy(delta)) return;

    final controller =
        FeedScrollScope.maybeOf(context) ??
        PrimaryScrollController.maybeOf(context);
    if (controller == null || !controller.hasClients) return;

    for (final pos in controller.positions) {
      if (!pos.hasContentDimensions) continue;
      pos.pointerScroll(delta);
      return;
    }
  }
}

/// **Margin (여백)** = empty app background without nav / panel controls.
///
/// Receives wheel / trackpad from this subtree and forwards to [FeedScrollBridge].
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

/// Wraps the feed scroll view — explicit web wheel handler on content + gaps.
class FeedScrollWheelWrapper extends StatelessWidget {
  const FeedScrollWheelWrapper({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        final delta = -event.scrollDelta.dy;
        if (delta == 0) return;
        FeedScrollBridge.scrollBy(delta);
      },
      child: child,
    );
  }
}

/// @deprecated Use [FeedWheelMarginSurface].
typedef FeedMarginWheelZone = FeedWheelMarginSurface;

/// @deprecated Use [FeedWheelMarginSurface].
typedef FeedScrollColumn = FeedWheelMarginSurface;

/// Full-width wrapper for feed list rows.
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
