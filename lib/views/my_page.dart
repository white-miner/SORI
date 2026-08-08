import 'package:flutter/material.dart';

import '../models/session_user.dart';
import '../routing/app_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/membership_progress.dart';
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
    final customer =
        customerId == null ? null : store.findCustomer(customerId);
    final remain = customer?.membershipRemainingVisits ?? 0;

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
          if (!isDirector && customer != null) ...[
            const SizedBox(height: 12),
            SoriCard(
              child: MembershipProgressView(customer: customer),
            ),
          ],
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
          if (isDirector) ...[
            const SizedBox(height: 20),
            const _SectionLabel('📊 AI 샵 경영 리포트'),
            const _AiShopReportCard(),
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

class _AiShopReportCard extends StatelessWidget {
  const _AiShopReportCard();

  @override
  Widget build(BuildContext context) {
    return SoriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: SoriTokens.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: SoriTokens.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 샵 경영 리포트',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '고객 차트 · 후기 키워드를 분석했어요',
                      style: TextStyle(
                        fontSize: 12,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _ReportInsight(
            emoji: '🔥',
            badge: '집중 투자',
            badgeColor: Color(0xFFFF6B4A),
            badgeBg: Color(0xFFFFF0EC),
            title: '반응 폭발 메뉴',
            body: '수분 장벽 케어 (리뷰 긍정 키워드 1위)',
          ),
          const SizedBox(height: 10),
          const _ReportInsight(
            emoji: '📉',
            badge: '축소/보완',
            badgeColor: Color(0xFF6B7280),
            badgeBg: Color(0xFFF3F4F6),
            title: '반응 저하 메뉴',
            body: '기본 윤곽 관리 (재방문 전환율 하락 추세)',
          ),
          const SizedBox(height: 10),
          const _ReportInsight(
            emoji: '💡',
            badge: 'AI 신규 제안',
            badgeColor: SoriTokens.primary,
            badgeBg: SoriTokens.primarySoft,
            title: '타겟 메뉴',
            body:
                "최근 고객 차트에서 '모공' 고민이 급증하고 있습니다. [쿨링 모공 디톡스] 메뉴 신설을 추천합니다.",
          ),
        ],
      ),
    );
  }
}

class _ReportInsight extends StatelessWidget {
  const _ReportInsight({
    required this.emoji,
    required this.badge,
    required this.badgeColor,
    required this.badgeBg,
    required this.title,
    required this.body,
  });

  final String emoji;
  final String badge;
  final Color badgeColor;
  final Color badgeBg;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SoriTokens.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SoriTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: SoriTokens.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: SoriTokens.textPrimary,
            ),
          ),
        ],
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
