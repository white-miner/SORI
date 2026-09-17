import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 터치·펜·트랙패드는 드래그 스크롤 허용, 마우스는 휠만 허용.
///
/// PC 웹에서 서명 패드 마우스 드래그가 부모 Scrollable/PageView에
/// 가로채이지 않도록 차트 작성 화면에 적용한다.
class SoriMouseWheelScrollBehavior extends MaterialScrollBehavior {
  const SoriMouseWheelScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}
