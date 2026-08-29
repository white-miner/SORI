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
///
/// Drag-to-dismiss: [enableDrag] defaults true. Prefer nesting scrollables
/// under [SoriSheetFrame] so the handle / top chrome can dismiss without the
/// scroll view stealing the gesture.
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

/// Solid-surface modal sheet with drag + keyboard insets enabled by default.
Future<T?> showSoriSolidBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool enableDrag = true,
  Color backgroundColor = SoriTokens.surface,
  double topRadius = 22,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: backgroundColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
    ),
    builder: builder,
  );
}

/// Sheet chrome: drag handle outside the scroll body so swipe-down dismiss works.
class SoriSheetFrame extends StatelessWidget {
  const SoriSheetFrame({
    super.key,
    required this.child,
    this.scrollController,
    this.maxHeightFactor = 0.92,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
    this.showHandle = true,
  });

  final Widget child;
  final ScrollController? scrollController;
  final double maxHeightFactor;
  final EdgeInsets padding;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * maxHeightFactor;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHandle)
                const Padding(
                  padding: EdgeInsets.only(top: 10, bottom: 6),
                  child: _SoriSheetDragHandle(),
                ),
              // Handle stays outside the scroll view so swipe-down dismiss works.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxH - (showHandle ? 28 : 0),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  // Do not auto-dismiss keyboard on scroll — preserves TextField focus.
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.manual,
                  padding: padding,
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoriSheetDragHandle extends StatelessWidget {
  const _SoriSheetDragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: SoriTokens.border,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}
