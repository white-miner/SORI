import 'package:flutter/material.dart';

import '../routing/app_router.dart';
import '../services/sori_store.dart';
import 'customer_list_page.dart';
import 'home_page.dart';
import 'message_history_page.dart';
import 'my_app.dart';
import 'shop_settings_page.dart';

/// 원장용 어드민 셸 — 고객 리뷰 페이지에서는 절대 마운트되지 않음.
class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _currentIndex = 0;
  final SoriStore _store = SoriStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  void _logout() {
    _store.logout();
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.home,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        title: Text(_store.shop.name),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2D3436),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '샵 설정',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ShopSettingsPage(),
                ),
              );
            },
            icon: const Icon(Icons.storefront_outlined),
          ),
          IconButton(
            tooltip: '로그아웃',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          MyHomePage(customers: _store.customers),
          CustomerListPage(store: _store),
          const MessageHistoryPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: MyApp.soriPurple,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '알림',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: '차트 관리',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            activeIcon: Icon(Icons.history),
            label: '메시지 이력',
          ),
        ],
      ),
    );
  }
}
