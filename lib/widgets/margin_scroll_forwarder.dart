import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Forwards wheel / trackpad scroll from empty margins to the feed scroll position.
class MarginScrollForwarder extends StatelessWidget {
  const MarginScrollForwarder({super.key, this.child});

  final Widget? child;

  static void forwardWheel(BuildContext context, PointerScrollEvent event) {
    final delta = -event.scrollDelta.dy;
    if (delta == 0) return;

    final primary = PrimaryScrollController.maybeOf(context);
    if (primary != null && primary.hasClients) {
      final pos = primary.position;
      if (pos.hasContentDimensions) {
        pos.pointerScroll(delta);
        return;
      }
    }

    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != null && scrollable.position.hasContentDimensions) {
      scrollable.position.pointerScroll(delta);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        forwardWheel(context, event);
      },
      child: child ?? const SizedBox.expand(),
    );
  }
}

/// Central feed column — full width/height hit target so gaps & side margins scroll.
class FeedScrollColumn extends StatelessWidget {
  const FeedScrollColumn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerSignal: (event) {
            if (event is! PointerScrollEvent) return;
            MarginScrollForwarder.forwardWheel(context, event);
          },
          child: ScrollConfiguration(
            behavior: const _FeedScrollBehavior(),
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Feed-only scroll behavior — mouse drag + wheel on web/desktop.
class _FeedScrollBehavior extends MaterialScrollBehavior {
  const _FeedScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
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
