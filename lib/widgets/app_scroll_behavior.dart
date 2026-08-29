import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// App-wide scroll behavior for web / desktop / mobile.
///
/// Accepts mouse drag, trackpad, and touch so feed and panels scroll naturally
/// on every platform. Applied at [MaterialApp.scrollBehavior] and in [main.dart].
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
