import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/session_user.dart';
import '../routing/app_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'admin_chart_writer_page.dart';
import 'customer_care_page.dart';
import 'customer_home_page.dart';
import 'director_home_page.dart';
import 'director_review_manage_page.dart';
import 'ikea_review_composer_page.dart';
import 'message_history_page.dart';
import 'my_page.dart';

/// 로그인 후 5탭 앱 셸 (원장/고객 모드 공통).
class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  final _store = SoriStore.instance;
  int _tab = 0;

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

  @override
  Widget build(BuildContext context) {
    final session = _store.session;
    if (session == null || !session.onboardingComplete) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: SoriTokens.primary)),
      );
    }

    final isDirector = session.activeMode == UserRole.director;
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
      const MessageHistoryPage(),
      MyPage(
        store: _store,
        onSelectTab: _selectTab,
      ),
    ];

    final reviewLabel = isDirector ? '리뷰 관리' : '리뷰 작성';

    return Scaffold(
      backgroundColor: SoriTokens.background,
      body: IndexedStack(index: _tab, children: pages),
      floatingActionButton: isDirector
          ? FloatingActionButton(
              tooltip: '새 차트 작성',
              onPressed: () => _quickWrite(context),
              backgroundColor: SoriTokens.primary,
              child: const Icon(Icons.edit_note_rounded, color: Colors.white),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _SoriBottomNav(
        currentIndex: _tab,
        isDirector: isDirector,
        reviewLabel: reviewLabel,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }

  Future<void> _quickWrite(BuildContext context) async {
    final customers = _store.customers;
    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('먼저 고객을 추가해 주세요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await openChartWriterForCustomer(
      context,
      store: _store,
      customer: customers.first,
    );
  }
}

Future<void> openChartWriterForCustomer(
  BuildContext context, {
  required SoriStore store,
  required Customer customer,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AdminChartWriterPage(
        store: store,
        customer: customer,
      ),
      fullscreenDialog: true,
    ),
  );
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
                    icon: Icons.notifications_none_rounded,
                    activeIcon: Icons.notifications_rounded,
                    label: '알림',
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
            Icon(selected ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
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
