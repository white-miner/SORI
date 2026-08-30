import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/session_user.dart';
import '../routing/sori_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_nav.dart';
import '../widgets/glass/sori_glass_app_bar_cluster.dart';
import '../widgets/right_sidebar.dart';
import '../widgets/floating_pill_nav.dart';
import '../widgets/margin_scroll_forwarder.dart';
import '../widgets/sori_logo.dart';
import 'app_settings_page.dart';
import 'case_archive_page.dart';
import 'message_history_page.dart';
import 'post_first_creation_page.dart';

/// 로그인 후 5탭 앱 셸 — [StatefulShellRoute] 로 하단바 고정.
class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  final _store = SoriStore.instance;

  /// PC push sidebar — YouTube-style expand / collapse (not overlay drawer).
  /// Default collapsed so the main work area stays wide on first load.
  bool _isSidebarExpanded = false;

  /// Store 전역 notify마다 셸을 리빌드하지 않도록 셸 관련 스냅샷만 추적.
  bool _lastHydrating = false;
  String? _lastSessionKey;
  UserRole? _lastMode;
  int _lastBadge = -1;
  String? _lastCommentPostId;
  bool _lastOnboarding = false;
  bool _lastHomeRefreshing = false;
  final ScrollController _pcFeedScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _captureShellSnapshot();
    _store.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_store.authHydrating) return;
      if (_store.session == null || !_store.session!.onboardingComplete) {
        context.go(AppPaths.login);
        return;
      }
      if (_store.session?.activeMode == UserRole.director) {
        unawaited(_store.refreshShopNotifications());
      }
    });
  }

  @override
  void dispose() {
    _pcFeedScrollController.dispose();
    _store.removeListener(_onChanged);
    super.dispose();
  }

  void _captureShellSnapshot() {
    final s = _store.session;
    _lastHydrating = _store.authHydrating;
    _lastSessionKey = s?.authUserId ?? s?.customerId ?? s?.phone;
    _lastMode = s?.activeMode;
    _lastOnboarding = s?.onboardingComplete ?? false;
    _lastCommentPostId = _store.activeCommentPostId;
    _lastBadge = s == null ? -1 : _notificationBadgeCount(s);
    _lastHomeRefreshing = _store.appHomeRefreshing;
  }

  bool _shellSnapshotChanged() {
    final s = _store.session;
    final hydrating = _store.authHydrating;
    final key = s?.authUserId ?? s?.customerId ?? s?.phone;
    final mode = s?.activeMode;
    final onboarding = s?.onboardingComplete ?? false;
    final comment = _store.activeCommentPostId;
    final badge = s == null ? -1 : _notificationBadgeCount(s);
    final homeRefresh = _store.appHomeRefreshing;
    return hydrating != _lastHydrating ||
        key != _lastSessionKey ||
        mode != _lastMode ||
        onboarding != _lastOnboarding ||
        comment != _lastCommentPostId ||
        badge != _lastBadge ||
        homeRefresh != _lastHomeRefreshing;
  }

  void _onChanged() {
    if (!mounted) return;
    if (_store.authHydrating) {
      if (!_lastHydrating) {
        _lastHydrating = true;
        setState(() {});
      }
      return;
    }
    if (_store.session == null || !_store.session!.onboardingComplete) {
      context.go(AppPaths.login);
      return;
    }
    final pendingTab = _store.pendingAppTab;
    if (pendingTab != null) {
      _store.pendingAppTab = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _selectTab(pendingTab.clamp(0, 4));
      });
    }
    if (!_shellSnapshotChanged()) return;
    _captureShellSnapshot();
    setState(() {});
  }

  void _selectTab(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _popRootOverlays() {
    final nav = rootNavigatorKey.currentState;
    if (nav == null || !nav.canPop()) return;
    nav.popUntil((route) => route.isFirst);
  }

  Future<void> _goHomeAndRefresh() async {
    if (_store.appHomeRefreshing) return;
    _store.closeCommentPanel();
    if (mounted) context.go(AppPaths.appHome);
    widget.navigationShell.goBranch(0, initialLocation: true);
    _popRootOverlays();
    await _store.refreshAppHomeFromLogo();
  }

  Future<void> _openNotifications() async {
    await _store.refreshShopNotifications();
    if (!mounted) return;
    await pushRootPage<void>(
      context,
      Scaffold(
        backgroundColor: SoriTokens.background,
        appBar: AppBar(
          title: const Text('알림'),
          backgroundColor: SoriTokens.surface,
          foregroundColor: SoriTokens.textPrimary,
          elevation: 0,
        ),
        body: MessageHistoryPage(embedded: true, store: _store),
      ),
    );
  }

  Future<void> _openArchive() async {
    await pushRootPage<void>(
      context,
      CaseArchivePage(store: _store),
    );
  }

  Future<void> _openSettings() async {
    await pushRootPage<void>(
      context,
      AppSettingsPage(store: _store),
    );
  }

  int _notificationBadgeCount(SessionUser session) {
    return _store.shellNotificationBadgeCount();
  }

  bool _isCustomerDetailRoute(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return path.startsWith('${AppPaths.appCustomers}/') &&
        path.length > AppPaths.appCustomers.length + 1;
  }

  @override
  Widget build(BuildContext context) {
    final session = _store.session;
    if (_store.authHydrating ||
        session == null ||
        !session.onboardingComplete) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: SoriTokens.primary),
        ),
      );
    }

    final isDirector = session.activeMode == UserRole.director;
    final reviewLabel = isDirector ? '리뷰 관리' : '리뷰 작성';
    final tab = widget.navigationShell.currentIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        // PC breakpoint — 800px+ (mobile layout preserved below).
        final wide = constraints.maxWidth >= 800;
        final extraWide = constraints.maxWidth >= 1200;
        // Mobile: hide shell AppBar only on customer detail for immersion.
        // My 탭은 셸 AppBar(+ / 알림 / 보관함 / 설정)를 유지한다 (S-A).
        final hideShellAppBar = !wide && _isCustomerDetailRoute(context);

        final appBar = hideShellAppBar
            ? null
            : _ShellAppBar(
                showLogo: true,
                logoRefreshing: _store.appHomeRefreshing,
                onLogoTap: _goHomeAndRefresh,
                showMenuButton: wide,
                onMenuTap: wide
                    ? () => setState(
                          () => _isSidebarExpanded = !_isSidebarExpanded,
                        )
                    : null,
                badgeCount: _notificationBadgeCount(session),
                onNotifications: _openNotifications,
                onPostFirst: () => PostFirstCreationPage.open(context),
                onArchive: _openArchive,
                onSettings: _openSettings,
              );

        if (!wide) {
          final shellBody = tab == 0
              ? FeedWheelMarginSurface(child: widget.navigationShell)
              : widget.navigationShell;
          return Scaffold(
            backgroundColor: SoriTokens.background,
            extendBody: true,
            appBar: appBar,
            body: shellBody,
            bottomNavigationBar: FloatingPillNav(
              currentIndex: tab,
              isDirector: isDirector,
              reviewLabel: reviewLabel,
              onTap: _selectTab,
            ),
          );
        }

        // PC: Row push-sidebar (no Scaffold.drawer overlay).
        final hasComment = _store.activeCommentPostId != null;
        final onHomeFeed = tab == 0;

        Widget pcBody = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PcSidePanel(
              expanded: _isSidebarExpanded,
              currentIndex: tab,
              isDirector: isDirector,
              onTap: _selectTab,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, bodyConstraints) {
                  const feedMaxWidth = 720.0;
                  const feedHalf = feedMaxWidth / 2;
                  const drawerTarget = 380.0;
                  final remainingRight =
                      (bodyConstraints.maxWidth / 2) - feedHalf;
                  final commentWidth =
                      remainingRight.clamp(0.0, drawerTarget);

                  final showDashboard = extraWide && !hasComment;

                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRect(
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  width: feedMaxWidth,
                                  height: bodyConstraints.maxHeight,
                                  child: widget.navigationShell,
                                ),
                              ),
                            ),
                          ),
                          if (showDashboard)
                            const SizedBox(
                              width: RightSidebar.width,
                              child: RightSidebar(dashboardOnly: true),
                            ),
                        ],
                      ),
                      if (hasComment)
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _store.closeCommentPanel(),
                          ),
                        ),
                      Positioned(
                        left: (bodyConstraints.maxWidth / 2) + feedHalf,
                        top: 0,
                        bottom: 0,
                        child: ClipRect(
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: hasComment ? commentWidth : 0,
                              child: hasComment
                                  ? const RightSidebar()
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );

        if (onHomeFeed) {
          pcBody = FeedScrollScopeBinder(
            controller: _pcFeedScrollController,
            child: FeedWheelMarginSurface(child: pcBody),
          );
        }

        return Scaffold(
          backgroundColor: SoriTokens.background,
          appBar: appBar,
          body: pcBody,
        );
      },
    );
  }
}

/// PC push sidebar — expands/collapses in-flow (YouTube-style).
class _PcSidePanel extends StatelessWidget {
  const _PcSidePanel({
    required this.expanded,
    required this.currentIndex,
    required this.isDirector,
    required this.onTap,
  });

  static const double expandedWidth = 240;
  static const double collapsedWidth = 72;

  final bool expanded;
  final int currentIndex;
  final bool isDirector;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final items = isDirector
        ? const [
            (Icons.home_outlined, Icons.home_rounded, '홈'),
            (Icons.people_outline, Icons.people_rounded, '고객'),
            (Icons.photo_camera_outlined, Icons.photo_camera_rounded, '촬영'),
            (Icons.groups_outlined, Icons.groups_rounded, '커뮤니티'),
            (Icons.person_outline_rounded, Icons.person_rounded, '마이'),
          ]
        : const [
            (Icons.home_outlined, Icons.home_rounded, '홈'),
            (Icons.spa_outlined, Icons.spa_rounded, '케어'),
            (Icons.rate_review_outlined, Icons.rate_review_rounded, '리뷰'),
            (Icons.groups_outlined, Icons.groups_rounded, '커뮤니티'),
            (Icons.person_outline_rounded, Icons.person_rounded, '마이'),
          ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      width: expanded ? expandedWidth : collapsedWidth,
      decoration: const BoxDecoration(
        color: SoriTokens.surface,
        border: Border(
          right: BorderSide(color: SoriTokens.border, width: 1),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
        children: [
          for (var i = 0; i < items.length; i++)
            _PcSideNavItem(
              icon: items[i].$1,
              selectedIcon: items[i].$2,
              label: items[i].$3,
              selected: currentIndex == i,
              expanded: expanded,
              onTap: () => onTap(i),
            ),
        ],
      ),
    );
  }
}

class _PcSideNavItem extends StatelessWidget {
  const _PcSideNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  static const Color _activeBg = Color(0xFFF1F1F1);
  static const Color _charcoal = Color(0xFF111111);
  static const Color _idle = Color(0xFF71717A);

  @override
  Widget build(BuildContext context) {
    final fg = selected ? _charcoal : _idle;
    final radius = BorderRadius.circular(10);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? 12 : 8,
        vertical: 2,
      ),
      child: Material(
        color: selected ? _activeBg : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          hoverColor: const Color(0xFFF1F1F1).withValues(alpha: 0.65),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 12 : 4,
              vertical: expanded ? 12 : 10,
            ),
            child: expanded
                ? Row(
                    children: [
                      Icon(
                        selected ? selectedIcon : icon,
                        size: 22,
                        color: fg,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: fg,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selected ? selectedIcon : icon,
                        size: 22,
                        color: fg,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: fg,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// 글래스모피즘 셸 AppBar — 로고 + (PC) 햄버거 + 알림.
class _ShellAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ShellAppBar({
    required this.showLogo,
    required this.badgeCount,
    required this.onNotifications,
    this.showMenuButton = false,
    this.onMenuTap,
    this.onPostFirst,
    this.onArchive,
    this.onSettings,
    this.onLogoTap,
    this.logoRefreshing = false,
  });

  final bool showLogo;
  final bool showMenuButton;
  final VoidCallback? onMenuTap;
  final int badgeCount;
  final VoidCallback onNotifications;
  final VoidCallback? onPostFirst;
  final VoidCallback? onArchive;
  final VoidCallback? onSettings;
  final VoidCallback? onLogoTap;
  final bool logoRefreshing;

  static const double toolbarHeight = 60;

  @override
  Size get preferredSize => const Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SoriTokens.surfaceElevated.withValues(alpha: 0.97),
        border: const Border(
          bottom: BorderSide(
            color: SoriTokens.border,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: toolbarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (showMenuButton)
                  IconButton(
                    tooltip: '메뉴',
                    onPressed: onMenuTap ?? () {},
                    icon: const Icon(Icons.menu_rounded, color: Colors.black87, size: 24),
                  ),
                if (showLogo) ...[
                  Padding(
                    padding: EdgeInsets.only(
                      left: showMenuButton ? 4 : 2,
                      right: 8,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _ShellLogoButton(
                        refreshing: logoRefreshing,
                        onTap: onLogoTap,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                SoriGlassAppBarCluster(
                  items: [
                    if (onPostFirst != null)
                      SoriGlassAppBarItem(
                        icon: Icons.add_rounded,
                        tooltip: '새 게시물',
                        onPressed: onPostFirst!,
                      ),
                    SoriGlassAppBarItem(
                      icon: Icons.notifications_rounded,
                      tooltip: '알림',
                      onPressed: onNotifications,
                      badgeCount: badgeCount,
                    ),
                    if (onArchive != null)
                      SoriGlassAppBarItem(
                        icon: Icons.inventory_2_rounded,
                        tooltip: '보관함',
                        onPressed: onArchive!,
                      ),
                    if (onSettings != null)
                      SoriGlassAppBarItem(
                        icon: Icons.settings_rounded,
                        tooltip: '설정',
                        onPressed: onSettings!,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// GNB 로고 — 홈 이동 + 새로고침.
class _ShellLogoButton extends StatelessWidget {
  const _ShellLogoButton({
    required this.refreshing,
    this.onTap,
  });

  final bool refreshing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: refreshing ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: '홈으로 · 새로고침',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: refreshing ? 0.45 : 1,
                  child: const SoriLogo(height: SoriLogo.gnbHeight),
                ),
                if (refreshing)
                  const Positioned(
                    right: -2,
                    bottom: -2,
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
