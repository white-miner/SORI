import 'package:flutter/material.dart';

/// Push above [AppShellPage] so [FloatingPillNav] is not visible under overlays.
Future<T?> pushRootPage<T extends Object?>(
  BuildContext context,
  Widget page, {
  bool fullscreenDialog = false,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    MaterialPageRoute<T>(
      builder: (_) => page,
      fullscreenDialog: fullscreenDialog,
    ),
  );
}

/// Root push with a custom [Route] (e.g. fade PageRouteBuilder).
Future<T?> pushRootRoute<T extends Object?>(
  BuildContext context,
  Route<T> route,
) {
  return Navigator.of(context, rootNavigator: true).push<T>(route);
}
