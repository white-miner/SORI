import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';
import '../widgets/sori_glass_surface.dart';

/// 플로팅 네비(FloatingPillNav)가 시트를 가리지 않도록 확보하는 하단 여백.
const double kSoriFloatingNavClearance = 100;

/// 태블릿/웹 뷰포트 — SafeArea + 키보드 + 홈 인디케이터.
EdgeInsets soriSheetSafePadding(BuildContext context) {
  final mq = MediaQuery.of(context);
  return EdgeInsets.only(
    bottom: mq.viewPadding.bottom + mq.viewInsets.bottom,
  );
}

double soriSheetBottomPadding(BuildContext context) {
  final mq = MediaQuery.of(context);
  return mq.viewInsets.bottom +
      kSoriFloatingNavClearance +
      mq.padding.bottom.clamp(0, 24);
}

/// 글래스모피즘 바텀시트 — transparent shell + [SoriGlassSurface].
Future<T?> showSoriModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    elevation: 0,
    useSafeArea: false,
    builder: (ctx) {
      return Padding(
        padding: soriSheetSafePadding(ctx),
        child: SoriGlassSurface(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: builder(ctx),
        ),
      );
    },
  );
}
