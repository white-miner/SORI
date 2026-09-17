/// PO desktop post detail — split-pane at 1024px, centered bundle max 1100px.
abstract final class PostLayoutBreakpoints {
  static const double desktopMinWidth = 1024;
  static const double splitPaneMaxWidth = 1100;
  static const double contentMaxWidth = 720;
  static const double splitPaneGap = 32;
  static const double sidebarWidth = 360;

  static bool isDesktopLayout(double width) => width >= desktopMinWidth;
}
