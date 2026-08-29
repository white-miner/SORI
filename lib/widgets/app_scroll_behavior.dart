import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Global scroll behavior — mouse drag, touch, trackpad/wheel on web & desktop.
class SoriScrollBehavior extends MaterialScrollBehavior {
  const SoriScrollBehavior();

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
    return const AlwaysScrollableScrollPhysics(
      parent: ClampingScrollPhysics(),
    );
  }
}

/// @deprecated Use [SoriScrollBehavior].
typedef AppScrollBehavior = SoriScrollBehavior;
