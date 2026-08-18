import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/session_user.dart';
import '../routing/sori_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/right_sidebar.dart';
import 'app_settings_page.dart';
import 'message_history_page.dart';

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
            backgroundColor: Colors.white,
            foregroundColor: SoriTokens.textPrimary,
            elevation: 0,
          ),
          body: const MessageHistoryPage(embedded: true),
        ),
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

  /// 셸 메인 탭 타이틀 — 전 페이지 동일 규격.
  String _titleForTab(bool isDirector, int tab) {
    if (isDirector) {
      return switch (tab) {
        0 => '홈',
        1 => '고객 관리',
        2 => '리뷰 관리',
        3 => '관리 케이스',
        4 => '마이페이지',
        _ => 'SORI',
      };
    }
    return switch (tab) {
      0 => '홈',
      1 => '케어',
      2 => '리뷰 작성',
      3 => '관리 케이스',
      4 => '마이페이지',
      _ => 'SORI',
    };
  }

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
                title: _titleForTab(isDirector, tab),
                badgeCount: _notificationBadgeCount(session),
                onNotifications: _openNotifications,
                onSettings: tab == 4 ? _openSettings : null,
              );

        if (!wide) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F6F8),
            extendBody: true,
            appBar: appBar,
            body: widget.navigationShell,
            bottomNavigationBar: _CenterReviewBottomNav(
              currentIndex: tab,
              isDirector: isDirector,
              reviewLabel: reviewLabel,
              onTap: _selectTab,
            ),
          );
        }

        // PC/Tablet: NavigationRail + Feed+CommentDrawer + optional RightSidebar
        final hasComment = _store.activeCommentPostId != null;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F6F8),
          appBar: appBar,
          body: Row(
            children: [
              _SoriNavigationRail(
                currentIndex: tab,
                isDirector: isDirector,
                onTap: _selectTab,
              ),
              Expanded(
                child: Stack(
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
                    Center(
                      child: GestureDetector(
                        onTap: () {},
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: SizedBox(
                                width: 720,
                                child: widget.navigationShell,
                              ),
                            ),
                            // Slide-out comment drawer attached to feed
                            ClipRect(
                              child: AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: hasComment ? 380 : 0,
                                  child: hasComment
                                      ? const RightSidebar()
                                      : const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (extraWide && !hasComment) ...[
                const VerticalDivider(width: 1, thickness: 1),
                const RightSidebar(dashboardOnly: true),
              ],
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
            color: Colors.white.withValues(alpha: 0.75),
            border: Border(
              right: BorderSide(
                color: Colors.white.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          child: NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: onTap,
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.transparent,
            indicatorColor: SoriTokens.primarySoft.withValues(alpha: 0.72),
            selectedIconTheme: const IconThemeData(color: SoriTokens.primary),
            unselectedIconTheme: IconThemeData(color: Colors.grey.shade600),
            selectedLabelTextStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: SoriTokens.primary,
            ),
            unselectedLabelTextStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
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
    this.onSettings,
  });

  final String title;
  final int badgeCount;
  final VoidCallback onNotifications;
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
                Colors.white.withValues(alpha: 0.88),
                Colors.white.withValues(alpha: 0.72),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: Color.lerp(
                      Colors.white,
                      const Color(0xFF6C5CE7),
                      0.15,
                    ) ??
                    Colors.white.withValues(alpha: 0.55),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.07),
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
                        Colors.white.withValues(alpha: 0.2),
                        Colors.white.withValues(alpha: 0.7),
                        Colors.white.withValues(alpha: 0.25),
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
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              height: 1.15,
                              letterSpacing: -0.35,
                              color: Colors.black.withValues(alpha: 0.82),
                            ),
                          ),
                        ),
                        _GlossyNotificationButton(
                          badgeCount: badgeCount,
                          onPressed: onNotifications,
                        ),
                        if (onSettings != null) ...[
                          const SizedBox(width: 8),
                          _GlossyIconButton(
                            icon: Icons.settings_rounded,
                            onPressed: onSettings!,
                            tooltip: '설정',
                          ),
                        ],
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

/// 하이그로시 원형 아이콘 버튼 (설정 등).
class _GlossyIconButton extends StatelessWidget {
  const _GlossyIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  static const Color _violet = Color(0xFF6C5CE7);
  static const Color _violetDeep = Color(0xFF4A3BCF);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 42,
            height: 42,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF3F0FF),
                    Color(0xFFE8E4FB),
                    Color(0xFFDCD6F7),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.85),
                  width: 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _violet.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: _violetDeep.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.55),
                            Colors.white.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.4, 0.75],
                        ),
                      ),
                    ),
                    Center(
                      child: Icon(
                        icon,
                        size: 22,
                        color: const Color(0xFF4A3BCF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 하이그로시 원형 알림 버튼 + 3D 젤리 뱃지.
class _GlossyNotificationButton extends StatelessWidget {
  const _GlossyNotificationButton({
    required this.badgeCount,
    required this.onPressed,
  });

  final int badgeCount;
  final VoidCallback onPressed;

  static const Color _violet = Color(0xFF6C5CE7);
  static const Color _violetDeep = Color(0xFF4A3BCF);

  @override
  Widget build(BuildContext context) {
    final showBadge = badgeCount > 0;
    final label = badgeCount > 9 ? '9+' : '$badgeCount';

    return Tooltip(
      message: '알림',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.35, -0.4),
                      radius: 1.05,
                      colors: [
                        Colors.white.withValues(alpha: 0.95),
                        const Color(0xFFEDE9FF),
                        const Color(0xFFD9D2FF),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                      width: 1.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _violet.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                      BoxShadow(
                        color: _violetDeep.withValues(alpha: 0.18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.55),
                                Colors.white.withValues(alpha: 0.08),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.4, 0.75],
                            ),
                          ),
                        ),
                        Align(
                          alignment: const Alignment(-0.5, -0.55),
                          child: Container(
                            width: 16,
                            height: 10,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.7),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Center(
                          child: Icon(
                            Icons.notifications_rounded,
                            size: 22,
                            color: Color(0xFF4A3BCF),
                            shadows: [
                              Shadow(
                                color: Color(0x33000000),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (showBadge)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        gradient: const RadialGradient(
                          center: Alignment(-0.3, -0.45),
                          radius: 1.1,
                          colors: [
                            Color(0xFFFF8A95),
                            Color(0xFFFF4D6A),
                            Color(0xFFE11D48),
                          ],
                          stops: [0.0, 0.45, 1.0],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF4D6A).withValues(
                              alpha: 0.55,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 젤리 하이라이트
                          Positioned(
                            top: 1,
                            left: 3,
                            right: 3,
                            height: 5,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(99),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.55),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                              shadows: [
                                Shadow(
                                  color: Color(0x44000000),
                                  blurRadius: 2,
                                  offset: Offset(0, 0.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

/// 중앙 리뷰 버튼이 바 위로 돌출되는 5탭 네비.
class _CenterReviewBottomNav extends StatelessWidget {
  const _CenterReviewBottomNav({
    required this.currentIndex,
    required this.isDirector,
    required this.reviewLabel,
    required this.onTap,
  });

  final int currentIndex;
  final bool isDirector;
  final String reviewLabel;
  final ValueChanged<int> onTap;

  static const double _barHeight = 64;
  static const double _fabSize = 58;
  static const double _protrude = 22;
  static const Color _accent = Color(0xFF6C5CE7);

  @override
  Widget build(BuildContext context) {
    final side = isDirector
        ? const [
            (Icons.home_outlined, Icons.home_rounded, '홈'),
            (Icons.people_outline, Icons.people, '고객 관리'),
            (Icons.photo_library_outlined, Icons.photo_library_rounded, '관리 케이스'),
            (Icons.person_outline_rounded, Icons.person_rounded, '마이'),
          ]
        : const [
            (Icons.home_outlined, Icons.home_rounded, '홈'),
            (Icons.spa_outlined, Icons.spa_rounded, '케어'),
            (Icons.photo_library_outlined, Icons.photo_library_rounded, '관리 케이스'),
            (Icons.person_outline_rounded, Icons.person_rounded, '마이'),
          ];

    final sideTabIndex = [0, 1, 3, 4];

    return SizedBox(
      height: _barHeight + _protrude + MediaQuery.paddingOf(context).bottom,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: _barHeight + MediaQuery.paddingOf(context).bottom,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                children: [
                  _NavItem(
                    icon: side[0].$1,
                    activeIcon: side[0].$2,
                    label: side[0].$3,
                    selected: currentIndex == sideTabIndex[0],
                    onTap: () => onTap(sideTabIndex[0]),
                  ),
                  _NavItem(
                    icon: side[1].$1,
                    activeIcon: side[1].$2,
                    label: side[1].$3,
                    selected: currentIndex == sideTabIndex[1],
                    onTap: () => onTap(sideTabIndex[1]),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(height: _fabSize / 2),
                          Text(
                            reviewLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: currentIndex == 2
                                  ? _accent
                                  : SoriTokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  _NavItem(
                    icon: side[2].$1,
                    activeIcon: side[2].$2,
                    label: side[2].$3,
                    selected: currentIndex == sideTabIndex[2],
                    onTap: () => onTap(sideTabIndex[2]),
                  ),
                  _NavItem(
                    icon: side[3].$1,
                    activeIcon: side[3].$2,
                    label: side[3].$3,
                    selected: currentIndex == sideTabIndex[3],
                    onTap: () => onTap(sideTabIndex[3]),
                  ),
                ],
              ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => onTap(2),
                child: _GlossyReviewFab(selected: currentIndex == 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 하이그로시 입체 중앙 리뷰 FAB.
class _GlossyReviewFab extends StatelessWidget {
  const _GlossyReviewFab({required this.selected});

  final bool selected;

  static const double _size = 58;
  static const Color _deepViolet = Color(0xFF4A3BCF);
  static const Color _midViolet = Color(0xFF6C5CE7);
  static const Color _brightViolet = Color(0xFF8B7CFF);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 1.05,
          colors: [
            _brightViolet,
            _midViolet,
            _deepViolet,
          ],
          stops: [0.0, 0.45, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: selected ? 0.42 : 0.28),
          width: selected ? 2.2 : 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: _midViolet.withValues(alpha: 0.55),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: _deepViolet.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 상단 반사광 림
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.34),
                    Colors.white.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.38, 0.72],
                ),
              ),
            ),
            // 좌상단 하이라이트 스페큘러
            Align(
              alignment: const Alignment(-0.55, -0.65),
              child: Container(
                width: 22,
                height: 14,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.55),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            const Center(
              child: Icon(
                Icons.chat_bubble_rounded,
                color: Colors.white,
                size: 26,
                shadows: [
                  Shadow(
                    color: Color(0x66000000),
                    blurRadius: 5,
                    offset: Offset(0, 1.5),
                  ),
                  Shadow(
                    color: Color(0x33000000),
                    blurRadius: 2,
                    offset: Offset(0, 0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF6C5CE7) : SoriTokens.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
