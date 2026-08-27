import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Forwards mouse-wheel / trackpad scroll from empty margins to the
/// nearest [PrimaryScrollController] (PC YouTube-style margin scroll).
class MarginScrollForwarder extends StatelessWidget {
  const MarginScrollForwarder({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        final primary = PrimaryScrollController.maybeOf(context);
        if (primary == null || !primary.hasClients) return;
        final pos = primary.position;
        if (!pos.hasContentDimensions) return;
        final next = (pos.pixels + event.scrollDelta.dy)
            .clamp(pos.minScrollExtent, pos.maxScrollExtent);
        if ((next - pos.pixels).abs() < 0.5) return;
        primary.jumpTo(next);
      },
      child: child ?? const SizedBox.expand(),
    );
  }
}
