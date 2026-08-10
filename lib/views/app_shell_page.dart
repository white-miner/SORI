import 'package:flutter/material.dart';

import '../models/session_user.dart';
import '../routing/app_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'chart_customer_picker_sheet.dart';
import 'customer_care_page.dart';
import 'customer_home_page.dart';
import 'director_customers_tab.dart';
import 'director_home_page.dart';
import 'director_review_manage_page.dart';
import 'ikea_review_composer_page.dart';
import 'message_history_page.dart';
import 'my_page.dart';
import 'success_cases_page.dart';

/// 로그인 후 5탭 앱 셸 (원장/고객 모드 공통).
class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  final _store = SoriStore.instance;
  int _tab = 0;

  static const _wideBreakpoint = 600.0;

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
    if (mounted) setState(() {});
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
    switch (_tab) {
      case 0:
        return '홈';
      case 1:
        return isDirector ? '고객 CRM' : '케어';
      case 2:
        return isDirector ? '리뷰 관리' : '리뷰 작성';
      case 3:
        return '성공 사례';
      case 4:
        return '마이';
      default:
        return 'SORI';
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _store.session;
    if (session == null || !session.onboardingComplete) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: SoriTokens.primary)),
      );
    }

    final isDirector = session.activeMode == UserRole.director;
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    final pages = <Widget>[
      isDirector
          ? DirectorHomePage(key: const ValueKey('d-home'), store: _store)
          : CustomerHomePage(
              key: const ValueKey('c-home'),
              store: _store,
              onSelectTab: _selectTab,
            ),
      isDirector
          ? DirectorCustomersTab(key: const ValueKey('d-cust'), store: _store)
          : CustomerCareTab(key: const ValueKey('c-care'), store: _store),
      isDirector
          ? DirectorReviewManagePage(
              key: const ValueKey('d-review'),
              store: _store,
            )
          : IkeaReviewComposerPage(
              key: const ValueKey('c-review'),
              store: _store,
            ),
      SuccessCasesPage(key: const ValueKey('success'), store: _store),
      MyPage(
        store: _store,
        onSelectTab: _selectTab,
      ),
    ];

    final reviewLabel = isDirector ? '리뷰 관리' : '리뷰 작성';

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: Text(_titleForTab(isDirector)),
        backgroundColor: Colors.white,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '알림',
            onPressed: _openNotifications,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          // 태블릿/PC: endTop FAB(보라 차트 버튼) 바로 왼쪽에 알림이 오도록 우측 여백
          if (isDirector && isWide) const SizedBox(width: 72),
        ],
      ),
      body: IndexedStack(index: _tab, children: pages),
      floatingActionButton: isDirector
          ? FloatingActionButton(
              tooltip: '새 차트 작성',
              onPressed: () => showChartCustomerPickerSheet(
                context,
                store: _store,
              ),
              backgroundColor: SoriTokens.primary,
              child: const Icon(Icons.edit_note_rounded, color: Colors.white),
            )
          : null,
      floatingActionButtonLocation: isWide
          ? FloatingActionButtonLocation.endTop
          : FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _SoriBottomNav(
        currentIndex: _tab,
        isDirector: isDirector,
        reviewLabel: reviewLabel,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

/// 중앙 리뷰 탭이 바 위로 돌출되는 커스텀 하단 네비.
class _SoriBottomNav extends StatelessWidget {
  const _SoriBottomNav({
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

  @override
  Widget build(BuildContext context) {
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
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: '홈',
                    selected: currentIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  _NavItem(
                    icon: isDirector
                        ? Icons.people_outline
                        : Icons.timeline_outlined,
                    activeIcon: isDirector ? Icons.people : Icons.timeline,
                    label: isDirector ? '고객' : '케어',
                    selected: currentIndex == 1,
                    onTap: () => onTap(1),
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
                                  ? SoriTokens.primary
                                  : SoriTokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  _NavItem(
                    icon: Icons.photo_library_outlined,
                    activeIcon: Icons.photo_library_rounded,
                    label: '성공 사례',
                    selected: currentIndex == 3,
                    onTap: () => onTap(3),
                  ),
                  _NavItem(
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: '마이',
                    selected: currentIndex == 4,
                    onTap: () => onTap(4),
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
                    color: SoriTokens.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: SoriTokens.primary.withValues(alpha: 0.35),
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
    final color =
        selected ? SoriTokens.primary : SoriTokens.textSecondary;
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
