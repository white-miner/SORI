import 'package:flutter/material.dart';

/// Holds parent vertical scroll while user drags the B/A slider horizontally.
class BaSliderScrollShield extends StatefulWidget {
  const BaSliderScrollShield({super.key, required this.child});

  final Widget child;

  @override
  State<BaSliderScrollShield> createState() => _BaSliderScrollShieldState();
}

class _BaSliderScrollShieldState extends State<BaSliderScrollShield> {
  ScrollHoldController? _hold;

  void _beginHold() {
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null) return;
    _hold ??= position.hold(() {});
  }

  void _endHold() {
    _hold?.cancel();
    _hold = null;
  }

  @override
  void dispose() {
    _endHold();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _beginHold(),
      onPointerUp: (_) => _endHold(),
      onPointerCancel: (_) => _endHold(),
      child: widget.child,
    );
  }
}
