import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/session_user.dart';
import '../routing/app_router.dart';
import '../services/sori_store.dart';
import 'admin_chart_writer_page.dart';
import 'director_home_page.dart';
import 'customer_home_page.dart';
import 'my_app.dart';

/// 로그인 후 셸 — activeMode에 따라 원장/고객 홈만 마운트.
class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

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
        body: Center(child: CircularProgressIndicator(color: MyApp.soriPurple)),
      );
    }

    final isDirector = session.activeMode == UserRole.director;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: isDirector
            ? DirectorHomePage(key: const ValueKey('director'), store: _store)
            : CustomerHomePage(key: const ValueKey('customer'), store: _store),
      ),
    );
  }
}

/// 프로필 헤더 + 원장↔고객 모드 토글 (공통).
class ModeProfileHeader extends StatelessWidget {
  const ModeProfileHeader({
    super.key,
    required this.store,
    required this.title,
    this.subtitle,
  });

  final SoriStore store;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final session = store.session!;
    final isDirector = session.activeMode == UserRole.director;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEF0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: MyApp.soriPurple.withValues(alpha: 0.15),
                child: Text(
                  session.name.characters.first,
                  style: const TextStyle(
                    color: MyApp.soriPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '로그아웃',
                onPressed: () {
                  store.logout();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRouter.home,
                    (_) => false,
                  );
                },
                icon: Icon(Icons.logout, color: Colors.grey.shade600, size: 20),
              ),
            ],
          ),
          if (session.canToggleMode) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F1FB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    isDirector ? '원장 모드' : '고객 모드',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: MyApp.soriPurple,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  const Text('고객', style: TextStyle(fontSize: 12)),
                  Switch.adaptive(
                    value: isDirector,
                    activeThumbColor: MyApp.soriPurple,
                    onChanged: (_) {
                      store.toggleActiveMode();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isDirector
                                ? '고객 모드로 전환했습니다'
                                : '원장 모드로 전환했습니다',
                          ),
                          backgroundColor: MyApp.soriPurple,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  const Text('원장', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ],
      ),
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
    ),
  );
}
