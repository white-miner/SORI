/// PO desktop post detail — split-pane at 1024px, 720px content, ~380px sidebar.
abstract final class PostLayoutBreakpoints {
  static const double desktopMinWidth = 1024;
  static const double contentMaxWidth = 720;
  static const double sidebarWidth = 380;

  static bool isDesktopLayout(double width) => width >= desktopMinWidth;
}
