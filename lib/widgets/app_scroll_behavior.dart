import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// PC 웹에서도 캐러셀·리스트를 마우스 드래그로 스와이프할 수 있게 합니다.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}
