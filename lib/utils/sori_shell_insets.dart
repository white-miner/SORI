import 'package:flutter/widgets.dart';

/// AppShell이 모바일에서 FloatingPillNav를 그리는지 하위 트리에 알린다.
///
/// [pillNavVisible]은 AppShell의 `width < 800` 분기와 같아야 한다.
/// PC 사이드바 레이아웃에서는 false 다.
class SoriShellInsetScope extends InheritedWidget {
  const SoriShellInsetScope({
    super.key,
    required this.pillNavVisible,
    required super.child,
  });

  final bool pillNavVisible;

  static SoriShellInsetScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SoriShellInsetScope>();
  }

  @override
  bool updateShouldNotify(SoriShellInsetScope oldWidget) {
    return oldWidget.pillNavVisible != pillNavVisible;
  }
}

/// 모바일 `extendBody` + FloatingPillNav occupancy의 스크롤 하단 inset SSOT.
///
/// Scaffold가 키보드에서 body 높이를 줄이므로 [MediaQuery.viewInsets]는
/// 더하지 않는다. bottom sheet · `resizeToAvoidBottomInset: false` 는 범위 밖.
abstract final class SoriShellInsets {
  static const double pillNavHeight = 64;
  static const double pillNavOuterBottomGap = 12;
  static const double contentClearance = 20;
  static const double pcBreakpoint = 800;

  /// FloatingPillNav가 body를 가리는지.
  ///
  /// AppShell scope가 있으면 그 값을 쓰고, 없으면 `width < 800` 으로 폴백한다.
  static bool pillNavOccupying(BuildContext context) {
    final scope = SoriShellInsetScope.maybeOf(context);
    if (scope != null) return scope.pillNavVisible;
    return MediaQuery.sizeOf(context).width < pcBreakpoint;
  }

  /// 스크롤 마지막 콘텐츠가 pill nav 아래로 들어가기 전에 확보할 하단 여백.
  ///
  /// 모바일 occupancy (scope 밖, viewPadding 유지):
  /// `64 + 12 + viewPadding.bottom + 20`
  ///
  /// AppShell `extendBody` + `bottomNavigationBar` 안에서는 Scaffold가 body의
  /// [MediaQueryData.viewPadding] bottom을 0으로 만들고, nav 위젯 높이를
  /// [MediaQueryData.padding] bottom에 넣는다. 그때는 nav 높이 + 20.
  ///
  /// PC occupancy는 0. [MediaQuery.viewInsets]는 더하지 않는다.
  static double scrollBottomInset(BuildContext context) {
    if (!pillNavOccupying(context)) return 0;
    final viewPad = MediaQuery.viewPaddingOf(context).bottom;
    final pad = MediaQuery.paddingOf(context).bottom;
    final navBlock = pillNavHeight + pillNavOuterBottomGap;
    if (viewPad == 0 && pad >= navBlock) {
      return pad + contentClearance;
    }
    return navBlock + viewPad + contentClearance;
  }
}
