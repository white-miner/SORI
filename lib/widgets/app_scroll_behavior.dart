import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// App-wide scroll behavior for web / desktop / mobile.
///
/// Accepts mouse drag, trackpad, and touch. Scroll physics are inherited
/// from [MaterialScrollBehavior] (Flutter platform default).
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
}

/// @deprecated Use [SoriScrollBehavior].
typedef AppScrollBehavior = SoriScrollBehavior;
