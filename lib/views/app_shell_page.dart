import 'package:flutter/material.dart';

import '../models/session_user.dart';
import '../routing/app_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/sori_logo.dart';
import 'chart_customer_picker_sheet.dart';
import 'customer_care_page.dart';
import 'customer_home_page.dart';
import 'director_customers_tab.dart';
import 'director_home_page.dart';
import 'message_history_page.dart';
import 'my_page.dart';
import 'success_cases_page.dart';

/// 로그인 후 앱 셸 — 원장/고객 권한별 탭 분리.
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
    if (!mounted) return;
    final isDirector =
        _store.session?.activeMode == UserRole.director;
    final maxIndex = isDirector ? 3 : 2;
    if (_tab > maxIndex) {
      _tab = 0;
    }
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
        2 => '성공 사례',
        3 => '마이',
        _ => 'SORI',
      };
    }
    return switch (_tab) {
      0 => '홈',
      1 => '케어',
      2 => '마이',
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

    final pages = isDirector
        ? <Widget>[
            DirectorHomePage(key: const ValueKey('d-home'), store: _store),
            DirectorCustomersTab(key: const ValueKey('d-cust'), store: _store),
            SuccessCasesPage(key: const ValueKey('d-success'), store: _store),
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
          // 홈 탭(Index 0)에서만 알림 아이콘 노출
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
              backgroundColor: SoriTokens.primary,
              child: const Icon(Icons.edit_note_rounded, color: Colors.white),
            )
          : null,
      floatingActionButtonLocation: isWide
          ? FloatingActionButtonLocation.endTop
          : FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _RoleBottomNav(
        currentIndex: safeIndex,
        isDirector: isDirector,
        onTap: _selectTab,
      ),
    );
  }
}

class _RoleBottomNav extends StatelessWidget {
  const _RoleBottomNav({
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
            (Icons.people_outline, Icons.people, '고객 관리'),
            (Icons.photo_library_outlined, Icons.photo_library_rounded, '성공 사례'),
            (Icons.person_outline_rounded, Icons.person_rounded, '마이'),
          ]
        : const [
            (Icons.home_outlined, Icons.home_rounded, '홈'),
            (Icons.spa_outlined, Icons.spa_rounded, '케어'),
            (Icons.person_outline_rounded, Icons.person_rounded, '마이'),
          ];

    return Container(
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
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                _NavItem(
                  icon: items[i].$1,
                  activeIcon: items[i].$2,
                  label: items[i].$3,
                  selected: currentIndex == i,
                  onTap: () => onTap(i),
                ),
            ],
          ),
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
    final color = selected ? SoriTokens.primary : SoriTokens.textSecondary;
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
