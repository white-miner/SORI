import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/session_user.dart';
import '../routing/sori_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'chart_customer_picker_sheet.dart';
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

  static const _wideBreakpoint = 600.0;
  static const _reviewAccent = Color(0xFF6C5CE7);

  @override
  void initState() {
    super.initState();
    _store.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    if (session == null || !session.onboardingComplete) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: SoriTokens.primary),
        ),
      );
    }

    final isDirector = session.activeMode == UserRole.director;
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final reviewLabel = isDirector ? '리뷰 관리' : '리뷰 작성';
    final tab = widget.navigationShell.currentIndex;
    final hideShellAppBar = _isCustomerDetailRoute(context);
    final shopName = _store.shop.name.trim().isEmpty
        ? 'SORI'
        : _store.shop.name.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: hideShellAppBar
          ? null
          : _ShellAppBar(
              title: _titleForTab(isDirector, tab),
              shopName: shopName,
              badgeCount: _notificationBadgeCount(session),
              showFabClearance: isDirector && isWide,
              onNotifications: _openNotifications,
            ),
      body: widget.navigationShell,
      floatingActionButton: isDirector && !hideShellAppBar
          ? FloatingActionButton(
              tooltip: '새 차트 작성',
              onPressed: () => showChartCustomerPickerSheet(
                context,
                store: _store,
              ),
              backgroundColor: _reviewAccent,
              child: const Icon(Icons.edit_note_rounded, color: Colors.white),
            )
          : null,
      floatingActionButtonLocation: isWide
          ? FloatingActionButtonLocation.endTop
          : FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _CenterReviewBottomNav(
        currentIndex: tab,
        isDirector: isDirector,
        reviewLabel: reviewLabel,
        onTap: _selectTab,
      ),
    );
  }
}

/// 통일된 슬림 셸 AppBar — 타이틀 + 샵 서브캡션 / 알림만.
class _ShellAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ShellAppBar({
    required this.title,
    required this.shopName,
    required this.badgeCount,
    required this.showFabClearance,
    required this.onNotifications,
  });

  final String title;
  final String shopName;
  final int badgeCount;
  final bool showFabClearance;
  final VoidCallback onNotifications;

  static const double toolbarHeight = 60;
  static const Color _border = Color(0xFFF0F0F0);

  @override
  Size get preferredSize => const Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: _border, width: 1),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: toolbarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            height: 1.15,
                            letterSpacing: -0.3,
                            color: Colors.black.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 1.1,
                            color: Colors.purple.shade300,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _NotificationBellButton(
                    badgeCount: badgeCount,
                    onPressed: onNotifications,
                  ),
                  if (showFabClearance) const SizedBox(width: 56),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton({
    required this.badgeCount,
    required this.onPressed,
  });

  final int badgeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final showBadge = badgeCount > 0;
    final label = badgeCount > 9 ? '9+' : '$badgeCount';

    return Tooltip(
      message: '알림',
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        icon: Badge(
          isLabelVisible: showBadge,
          backgroundColor: const Color(0xFFFF5F6D),
          label: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: Icon(
            Icons.notifications_none_rounded,
            size: 24,
            color: Colors.black.withValues(alpha: 0.75),
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
            child: Container(
              height: _barHeight + MediaQuery.paddingOf(context).bottom,
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              decoration: BoxDecoration(
                color: SoriTokens.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
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
