import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/session_user.dart';
import '../routing/sori_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/right_sidebar.dart';
import '../widgets/floating_pill_nav.dart';
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

  @override
  void initState() {
    super.initState();
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

  void _onChanged() {
    if (!mounted) return;
    if (_store.authHydrating) {
      setState(() {});
      return;
    }
    if (_store.session == null || !_store.session!.onboardingComplete) {
      context.go(AppPaths.login);
      return;
    }
    setState(() {});
  }

  void _selectTab(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: SoriTokens.background,
          appBar: AppBar(
            title: const Text('알림'),
            backgroundColor: SoriTokens.surface,
            foregroundColor: SoriTokens.textPrimary,
            elevation: 0,
          ),
          body: const MessageHistoryPage(embedded: true),
        ),
      ),
    );
  }

  Future<void> _openArchive() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CaseArchivePage(store: _store),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppSettingsPage(store: _store),
      ),
    );
  }

  String _brandTitle() => 'Sori';

  int _notificationBadgeCount(SessionUser session) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (session.activeMode == UserRole.director) {
      final careToday = _store.customersForDate(today).length;
      final reviewReq = _store.reviewRequestedCustomerIds.length;
      return (careToday + reviewReq).clamp(0, 99);
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
    final hideShellAppBar = _isCustomerDetailRoute(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final extraWide = constraints.maxWidth >= 1200;

        final appBar = hideShellAppBar
            ? null
            : _ShellAppBar(
                title: _brandTitle(),
                badgeCount: _notificationBadgeCount(session),
                onNotifications: _openNotifications,
                onPostFirst: (tab == 0 || tab == 4)
                    ? () => PostFirstCreationPage.open(context)
                    : null,
                onArchive: tab == 3 ? _openArchive : null,
                onSettings: tab == 4 ? _openSettings : null,
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

        // PC/Tablet: rail + stacked feed (fixed center) + comment drawer
        final hasComment = _store.activeCommentPostId != null;

        return Scaffold(
          backgroundColor: SoriTokens.background,
          appBar: appBar,
          body: Row(
            children: [
              _SoriNavigationRail(
                currentIndex: tab,
                isDirector: isDirector,
                onTap: _selectTab,
              ),
              Expanded(
                child: LayoutBuilder(
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
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              if (_store.activeCommentPostId != null) {
                                _store.closeCommentPanel();
                              }
                            },
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
              ),
            ],
          ),
        );
      },
    );
  }
}

/// PC/태블릿용 좌측 네비게이션 레일.
class _SoriNavigationRail extends StatelessWidget {
  const _SoriNavigationRail({
    required this.currentIndex,
    required this.isDirector,
    required this.onTap,
  });

  final int currentIndex;
  final bool isDirector;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final destinations = isDirector
        ? const [
            NavigationRailDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: Text('홈'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: Text('고객 관리'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.rate_review_outlined),
              selectedIcon: Icon(Icons.rate_review_rounded),
              label: Text('리뷰 관리'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.photo_library_outlined),
              selectedIcon: Icon(Icons.photo_library_rounded),
              label: Text('관리 케이스'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: Text('마이페이지'),
            ),
          ]
        : const [
            NavigationRailDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: Text('홈'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.spa_outlined),
              selectedIcon: Icon(Icons.spa_rounded),
              label: Text('케어'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.rate_review_outlined),
              selectedIcon: Icon(Icons.rate_review_rounded),
              label: Text('리뷰 작성'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.photo_library_outlined),
              selectedIcon: Icon(Icons.photo_library_rounded),
              label: Text('관리 케이스'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: Text('마이페이지'),
            ),
          ];

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: SoriTokens.surface.withValues(alpha: 0.92),
            border: const Border(
              right: BorderSide(
                color: SoriTokens.outlinePurple,
                width: 1,
              ),
            ),
          ),
          child: NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: onTap,
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.transparent,
            indicatorColor: SoriTokens.primarySoft,
            selectedIconTheme: const IconThemeData(color: SoriTokens.primary),
            unselectedIconTheme:
                const IconThemeData(color: SoriTokens.textSecondary),
            selectedLabelTextStyle: const TextStyle(
              color: SoriTokens.primary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
            unselectedLabelTextStyle: const TextStyle(
              color: SoriTokens.textSecondary,
              fontSize: 11,
            ),
            leading: const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 16),
              child: Text(
                'SORI',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: SoriTokens.primary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            destinations: destinations,
          ),
        ),
      ),
    );
  }
}

/// 글래스모피즘 셸 AppBar — 메인 타이틀 + 하이그로시 알림.
class _ShellAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ShellAppBar({
    required this.title,
    required this.badgeCount,
    required this.onNotifications,
    this.onPostFirst,
    this.onArchive,
    this.onSettings,
  });

  final String title;
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
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                SoriTokens.surfaceElevated.withValues(alpha: 0.92),
                SoriTokens.background.withValues(alpha: 0.88),
              ],
            ),
            border: const Border(
              bottom: BorderSide(
                color: SoriTokens.outlinePurple,
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: SoriTokens.primary.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1.2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        SoriTokens.primary.withValues(alpha: 0.1),
                        SoriTokens.outlinePurple,
                        SoriTokens.primary.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: SizedBox(
                  height: toolbarHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                              height: 1.15,
                              letterSpacing: -0.4,
                              color: Colors.white,
                            ),
                          ),
                        ),
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
            ],
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
    final iconWidget = Icon(icon, size: 22, color: Colors.white);
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        splashRadius: 20,
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: badgeCount > 0
            ? Badge(
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
