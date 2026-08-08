import 'package:flutter/material.dart';

import '../models/session_user.dart';
import '../routing/app_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/sori_card.dart';
import 'shop_settings_page.dart';

class MyPage extends StatelessWidget {
  const MyPage({super.key, required this.store});

  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    final session = store.session!;
    final customerId = session.customerId;
    final charts = customerId == null
        ? store.charts
        : store.chartsForCustomer(customerId);
    final reviewCount = charts
        .where((c) => store.reviewForChart(c.id) != null)
        .length;
    final latest = customerId == null ? null : store.latestChart(customerId);
    final remain = latest == null
        ? 0
        : (10 - latest.visitNumber).clamp(0, 99);

    final isDirector = session.activeMode == UserRole.director;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          SoriCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: SoriTokens.primarySoft,
                  child: Text(
                    session.name.characters.first,
                    style: const TextStyle(
                      color: SoriTokens.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${session.phone} · ${session.providerLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: SoriTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: '내 소통 리뷰',
                  value: '$reviewCount',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: isDirector ? '등록 고객' : '회원권 남은 회차',
                  value: isDirector
                      ? '${store.customers.length}'
                      : '$remain',
                ),
              ),
            ],
          ),
          if (session.canToggleMode) ...[
            const SizedBox(height: 16),
            SoriCard(
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded, color: SoriTokens.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isDirector ? '원장 모드' : '고객 모드',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Switch.adaptive(
                    value: isDirector,
                    activeThumbColor: SoriTokens.primary,
                    onChanged: (_) {
                      store.toggleActiveMode();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isDirector ? '고객 모드로 전환' : '원장 모드로 전환',
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: SoriTokens.primary,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          const _SectionLabel('설정 / 관리'),
          SoriCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (session.shopSetupComplete || isDirector)
                  _MenuTile(
                    icon: Icons.storefront_outlined,
                    title: '샵 프로필',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ShopSettingsPage(),
                        ),
                      );
                    },
                  ),
                const Divider(height: 1),
                _MenuTile(
                  icon: Icons.notifications_outlined,
                  title: '알림 설정',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('알림 설정은 준비 중이에요'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                _MenuTile(
                  icon: Icons.help_outline,
                  title: '고객센터',
                  onTap: () {},
                ),
                const Divider(height: 1),
                _MenuTile(
                  icon: Icons.logout,
                  title: '로그아웃',
                  danger: true,
                  onTap: () {
                    store.logout();
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRouter.home,
                      (_) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SoriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: SoriTokens.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: SoriTokens.textSecondary,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: danger ? Colors.redAccent : SoriTokens.textPrimary,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: danger ? Colors.redAccent : SoriTokens.textPrimary,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: SoriTokens.textSecondary),
      onTap: onTap,
    );
  }
}
