import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Forwards wheel / trackpad scroll from PC side margins to the feed scroll position.
///
/// Only used on empty margin areas outside the centered feed column — never wrap
/// the scroll view itself (that breaks native mouse-wheel handling).
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

/// Ensures the feed column fills the viewport width/height for hit-testing gaps.
/// Does NOT intercept pointer/wheel events — scroll views handle those natively.
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
