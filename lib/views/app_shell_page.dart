import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/session_user.dart';
import '../routing/app_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'admin_chart_writer_page.dart';
import 'customer_home_page.dart';
import 'director_home_page.dart';
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
          : CustomerHomePage(key: const ValueKey('c-home'), store: _store),
      isDirector
          ? DirectorCustomersTab(key: const ValueKey('d-cust'), store: _store)
          : CustomerCareTab(key: const ValueKey('c-care'), store: _store),
      const _ComposeTabPlaceholder(),
      const MessageHistoryPage(),
      MyPage(store: _store),
    ];

    return Scaffold(
      backgroundColor: SoriTokens.background,
      body: IndexedStack(index: _tab, children: pages),
      floatingActionButton: isDirector && (_tab == 0 || _tab == 1)
          ? FloatingActionButton(
              onPressed: () => _quickWrite(context),
              backgroundColor: SoriTokens.primary,
              child: const Icon(Icons.edit_note_rounded, color: Colors.white),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: SoriTokens.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _tab,
            onTap: (i) {
              if (i == 2) {
                if (isDirector) {
                  _quickWrite(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('원장님이 열어 둔 리뷰에서 소통할 수 있어요'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return;
              }
              setState(() => _tab = i);
            },
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: '홈',
              ),
              BottomNavigationBarItem(
                icon: Icon(isDirector ? Icons.people_outline : Icons.timeline_outlined),
                activeIcon: Icon(isDirector ? Icons.people : Icons.timeline),
                label: isDirector ? '고객' : '케어',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: SoriTokens.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDirector ? Icons.add : Icons.chat_bubble_outline,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                label: isDirector ? '작성' : '소통',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.notifications_none_rounded),
                activeIcon: Icon(Icons.notifications_rounded),
                label: '알림',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: '마이',
              ),
            ],
          ),
        ),
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

class _ComposeTabPlaceholder extends StatelessWidget {
  const _ComposeTabPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
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
