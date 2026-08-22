import 'package:flutter/material.dart';

/// 플로팅 네비(FloatingPillNav)가 시트를 가리지 않도록 확보하는 하단 여백.
/// `useRootNavigator: true`와 함께 방어적으로 사용한다.
const double kSoriFloatingNavClearance = 100;

/// 키보드 inset + 플로팅 바 클리어런스 + 시스템 safe bottom.
double soriSheetBottomPadding(BuildContext context) {
  final mq = MediaQuery.of(context);
  return mq.viewInsets.bottom +
      kSoriFloatingNavClearance +
      mq.padding.bottom.clamp(0, 24);
}

/// 앱 전역 권장 바텀시트 — 루트 네비게이터 위에 올려 플로팅 바를 덮는다.
Future<T?> showSoriModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool enableDrag = true,
  ShapeBorder? shape,
  Clip? clipBehavior,
  double? elevation,
  bool useSafeArea = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: backgroundColor,
    shape: shape,
    clipBehavior: clipBehavior,
    elevation: elevation,
    useSafeArea: useSafeArea,
    builder: builder,
  );
}
