import 'package:flutter/material.dart';

import '../models/session_user.dart';
import '../routing/app_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/sori_logo.dart';
import 'chart_customer_picker_sheet.dart';
import 'customer_care_page.dart';
import 'customer_home_page.dart';
import 'customer_management_cases_page.dart';
import 'customer_review_dashboard_page.dart';
import 'director_customers_tab.dart';
import 'director_home_page.dart';
import 'director_review_manage_page.dart';
import 'message_history_page.dart';
import 'my_page.dart';
import 'success_cases_page.dart';

/// 로그인 후 5탭 앱 셸 — 중앙 리뷰 메인 버튼 복구.
class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  final _store = SoriStore.instance;
  int _tab = 0;

  static const _wideBreakpoint = 600.0;
  static const _reviewAccent = Color(0xFF6C5CE7);

  @override
  void initState() {
    super.initState();
    _store.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_store.session == null || !_store.session!.onboardingComplete) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.home,
          (_) => false,
        );
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
    if (_tab > 4) _tab = 0;
    setState(() {});
  }

  void _selectTab(int index) {
    setState(() => _tab = index);
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

  String _titleForTab(bool isDirector) {
    if (isDirector) {
      return switch (_tab) {
        0 => '홈',
        1 => '고객 관리',
        2 => '리뷰 관리',
        3 => '관리 케이스',
        4 => '마이',
        _ => 'SORI',
      };
    }
    return switch (_tab) {
      0 => '홈',
      1 => '케어',
      2 => '리뷰 작성',
      3 => '관리 케이스',
      4 => '마이',
      _ => 'SORI',
    };
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

    final pages = isDirector
        ? <Widget>[
            DirectorHomePage(key: const ValueKey('d-home'), store: _store),
            DirectorCustomersTab(key: const ValueKey('d-cust'), store: _store),
            DirectorReviewManagePage(
              key: const ValueKey('d-review'),
              store: _store,
            ),
            SuccessCasesPage(key: const ValueKey('d-cases'), store: _store),
            MyPage(
              key: const ValueKey('d-my'),
              store: _store,
              onSelectTab: _selectTab,
            ),
          ]
        : <Widget>[
            CustomerHomePage(
              key: const ValueKey('c-home'),
              store: _store,
              onSelectTab: _selectTab,
            ),
            CustomerCareTab(key: const ValueKey('c-care'), store: _store),
            CustomerReviewDashboardPage(
              key: const ValueKey('c-review'),
              store: _store,
            ),
            CustomerManagementCasesPage(
              key: const ValueKey('c-cases'),
              store: _store,
            ),
            MyPage(
              key: const ValueKey('c-my'),
              store: _store,
              onSelectTab: _selectTab,
            ),
          ];

    final safeIndex = _tab.clamp(0, pages.length - 1);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: Row(
          children: [
            const SoriLogo(width: 24, height: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _titleForTab(isDirector),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
        actions: [
          if (safeIndex == 0)
            IconButton(
              tooltip: '알림',
              onPressed: _openNotifications,
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          if (isDirector && isWide && safeIndex == 0)
            const SizedBox(width: 72),
        ],
      ),
      body: IndexedStack(index: safeIndex, children: pages),
      floatingActionButton: isDirector
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
        currentIndex: safeIndex,
        isDirector: isDirector,
        reviewLabel: reviewLabel,
        onTap: _selectTab,
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

    // side indices map to tabs 0,1,3,4 (center is 2)
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: _fabSize,
                  height: _fabSize,
                  decoration: BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: currentIndex == 2
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ],
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
