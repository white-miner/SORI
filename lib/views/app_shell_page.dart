import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/session_user.dart';
import '../routing/sori_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_nav.dart';
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
  final GlobalKey<ScaffoldState> _pcScaffoldKey = GlobalKey<ScaffoldState>();

  /// Store 전역 notify마다 셸을 리빌드하지 않도록 셸 관련 스냅샷만 추적.
  bool _lastHydrating = false;
  String? _lastSessionKey;
  UserRole? _lastMode;
  int _lastBadge = -1;
  String? _lastCommentPostId;
  bool _lastOnboarding = false;

  @override
  void initState() {
    super.initState();
    _captureShellSnapshot();
    _store.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_store.authHydrating) return;
      if (_store.session == null || !_store.session!.onboardingComplete) {
        context.go(AppPaths.login);
      }
    });
  }

  @override
  void dispose() {
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
  }

  bool _shellSnapshotChanged() {
    final s = _store.session;
    final hydrating = _store.authHydrating;
    final key = s?.authUserId ?? s?.customerId ?? s?.phone;
    final mode = s?.activeMode;
    final onboarding = s?.onboardingComplete ?? false;
    final comment = _store.activeCommentPostId;
    final badge = s == null ? -1 : _notificationBadgeCount(s);
    return hydrating != _lastHydrating ||
        key != _lastSessionKey ||
        mode != _lastMode ||
        onboarding != _lastOnboarding ||
        comment != _lastCommentPostId ||
        badge != _lastBadge;
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

  Future<void> _openNotifications() async {
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
        body: const MessageHistoryPage(embedded: true),
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (session.activeMode == UserRole.director) {
      final careToday = _store.customersForDate(today).length;
      final reviewReq = _store.reviewRequestedPendingCount;
      final unreplied = _store.reviewUnrepliedCount;
      return (careToday + reviewReq + unreplied).clamp(0, 99);
    }
    final cid = session.customerId;
    if (cid != null && _store.isReviewRequested(cid)) return 1;
    return 0;
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
        // Mobile: hide shell AppBar on My / customer detail for immersion.
        // PC: always keep AppBar so hamburger can open Scaffold.drawer.
        final hideShellAppBar = !wide &&
            (tab == 4 || _isCustomerDetailRoute(context));

        final appBar = hideShellAppBar
            ? null
            : _ShellAppBar(
                showLogo: true,
                showMenuButton: wide,
                onMenuTap: wide
                    ? () {
                        final scaffold = _pcScaffoldKey.currentState;
                        if (scaffold == null) return;
                        if (scaffold.isDrawerOpen) {
                          scaffold.closeDrawer();
                        } else {
                          scaffold.openDrawer();
                        }
                      }
                    : null,
                badgeCount: _notificationBadgeCount(session),
                onNotifications: _openNotifications,
                onPostFirst: tab == 0
                    ? () => PostFirstCreationPage.open(context)
                    : null,
                onArchive: tab == 0 || tab == 3 ? _openArchive : null,
                onSettings: null,
              );

        if (!wide) {
          return Scaffold(
            backgroundColor: SoriTokens.background,
            extendBody: true,
            appBar: appBar,
            body: widget.navigationShell,
            bottomNavigationBar: FloatingPillNav(
              currentIndex: tab,
              isDirector: isDirector,
              reviewLabel: reviewLabel,
              onTap: _selectTab,
            ),
          );
        }

        // PC: Scaffold.drawer (toggle) + centered feed + margin scroll
        final hasComment = _store.activeCommentPostId != null;

        return Scaffold(
          key: _pcScaffoldKey,
          backgroundColor: SoriTokens.background,
          appBar: appBar,
          drawer: _PcNavDrawer(
            currentIndex: tab,
            isDirector: isDirector,
            onTap: (i) {
              Navigator.of(context).maybePop();
              _selectTab(i);
            },
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              const feedMaxWidth = 720.0;
              const feedHalf = feedMaxWidth / 2;
              const drawerTarget = 380.0;
              final remainingRight =
                  (constraints.maxWidth / 2) - feedHalf;
              final drawerWidth = remainingRight.clamp(0.0, drawerTarget);

              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  const Positioned.fill(
                    child: MarginScrollForwarder(),
                  ),
                  if (hasComment)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _store.closeCommentPanel(),
                      ),
                    ),
                  if (extraWide && !hasComment)
                    const Positioned(
                      top: 0,
                      right: 0,
                      bottom: 0,
                      child: RightSidebar(dashboardOnly: true),
                    ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: feedMaxWidth,
                      ),
                      child: SizedBox(
                        width: feedMaxWidth,
                        child: widget.navigationShell,
                      ),
                    ),
                  ),
                  Positioned(
                    left: (constraints.maxWidth / 2) + feedHalf,
                    top: 0,
                    bottom: 0,
                    child: ClipRect(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: hasComment ? drawerWidth : 0,
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
        );
      },
    );
  }
}

/// PC Scaffold drawer — opens from hamburger, closes on barrier tap.
class _PcNavDrawer extends StatelessWidget {
  const _PcNavDrawer({
    required this.currentIndex,
    required this.isDirector,
    required this.onTap,
  });

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

    return Drawer(
      backgroundColor: SoriTokens.surface,
      width: 280,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              child: Row(
                children: [
                  const IconTheme(
                    data: IconThemeData(),
                    child: SoriLogo(height: SoriLogo.gnbHeight),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                    color: SoriTokens.textCharcoal,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            for (var i = 0; i < items.length; i++)
              _DrawerNavItem(
                icon: items[i].$1,
                selectedIcon: items[i].$2,
                label: items[i].$3,
                selected: currentIndex == i,
                extended: true,
                onTap: () => onTap(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _DrawerNavItem extends StatelessWidget {
  const _DrawerNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? SoriTokens.textCharcoal : SoriTokens.tabUnselected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected ? SoriTokens.tabCapsuleBg : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: extended ? 14 : 0),
            child: Row(
              mainAxisAlignment: extended
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(selected ? selectedIcon : icon, size: 22, color: fg),
                if (extended) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w500,
                        color: fg,
                      ),
                    ),
                  ),
                ],
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
  });

  final bool showLogo;
  final bool showMenuButton;
  final VoidCallback? onMenuTap;
  final int badgeCount;
  final VoidCallback onNotifications;
  final VoidCallback? onPostFirst;
  final VoidCallback? onArchive;
  final VoidCallback? onSettings;

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
                  _FlatAppBarIcon(
                    tooltip: '메뉴',
                    icon: Icons.menu,
                    onPressed: onMenuTap ?? () {},
                  ),
                if (showLogo) ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 4, right: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconTheme(
                        data: IconThemeData(),
                        child: SoriLogo(height: SoriLogo.gnbHeight),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (onPostFirst != null)
                  _FlatAppBarIcon(
                    tooltip: '새 게시물',
                    icon: Icons.add_outlined,
                    onPressed: onPostFirst!,
                  ),
                _FlatAppBarIcon(
                  tooltip: '알림',
                  icon: Icons.notifications_none_outlined,
                  onPressed: onNotifications,
                  badgeCount: badgeCount,
                ),
                if (onArchive != null)
                  _FlatAppBarIcon(
                    tooltip: '보관함',
                    icon: Icons.inventory_2_outlined,
                    onPressed: onArchive!,
                  ),
                if (onSettings != null)
                  _FlatAppBarIcon(
                    tooltip: '설정',
                    icon: Icons.settings_outlined,
                    onPressed: onSettings!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 배경·그림자 없는 플랫 AppBar 아이콘 (M3 IconButton 톤 배경 회피).
class _FlatAppBarIcon extends StatelessWidget {
  const _FlatAppBarIcon({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 22, color: SoriTokens.textCharcoal);
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        splashRadius: 20,
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: SoriTokens.textCharcoal,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: badgeCount > 0
            ? Badge(
                backgroundColor: SoriTokens.systemRed,
                label: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: iconWidget,
              )
            : iconWidget,
      ),
    );
  }
}
