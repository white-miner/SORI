import 'package:flutter/material.dart';

import '../models/session_user.dart';
import '../routing/app_router.dart';
import '../services/director_stats.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/membership_progress.dart';
import '../widgets/review_qr_modal.dart';
import '../widgets/sori_card.dart';
import 'customer_review_history_page.dart';
import 'service_menu_page.dart';
import 'shop_settings_page.dart';

class MyPage extends StatelessWidget {
  const MyPage({
    super.key,
    required this.store,
    this.onSelectTab,
  });

  final SoriStore store;
  final ValueChanged<int>? onSelectTab;

  Future<void> _openShopSettings(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ShopSettingsPage(),
      ),
    );
    // AppShell이 store listener로 이미 재빌드하지만, 탭 복귀 직후 확실히 반영.
  }

  String _avatarLetter({
    required bool useShopProfile,
    required String shopName,
    required String ownerName,
    required String sessionName,
  }) {
    if (useShopProfile) {
      final source = shopName.isNotEmpty
          ? shopName
          : (ownerName.isNotEmpty ? ownerName : sessionName);
      if (source.isNotEmpty) return source.characters.first;
    }
    if (sessionName.isNotEmpty) return sessionName.characters.first;
    return 'S';
  }

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
    final showManage = isDirector || session.shopSetupComplete;
    final shop = store.shop;
    final shopName = shop.name.trim();
    final ownerName = (shop.ownerName ?? '').trim();
    final hasShopProfile = shopName.isNotEmpty && ownerName.isNotEmpty;
    final useShopProfile = isDirector || showManage;

    return ColoredBox(
      color: SoriTokens.background,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            SoriCard(
              onTap: useShopProfile ? () => _openShopSettings(context) : null,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: SoriTokens.primarySoft,
                    child: Text(
                      _avatarLetter(
                        useShopProfile: useShopProfile,
                        shopName: shopName,
                        ownerName: ownerName,
                        sessionName: session.name,
                      ),
                      style: const TextStyle(
                        color: SoriTokens.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: useShopProfile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasShopProfile
                                    ? '$shopName / 원장 $ownerName'
                                    : '샵 정보를 등록해 주세요 〉',
                                style: TextStyle(
                                  fontSize: hasShopProfile ? 17 : 15,
                                  fontWeight: FontWeight.w800,
                                  color: hasShopProfile
                                      ? SoriTokens.textPrimary
                                      : SoriTokens.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                hasShopProfile
                                    ? '${session.phone} · ${session.providerLabel}'
                                    : '터치하여 샵 이름 · 원장명을 등록하세요',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: SoriTokens.textSecondary,
                                ),
                              ),
                            ],
                          )
                        : Column(
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
                  if (useShopProfile)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: SoriTokens.textSecondary,
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
                    onTap: isDirector
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    CustomerReviewHistoryPage(store: store),
                              ),
                            );
                          },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: isDirector ? '등록 고객' : '회원권 남은 회차',
                    value: isDirector
                        ? '${store.customers.length}'
                        : '$remain',
                    onTap: () => onSelectTab?.call(1),
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
            if (showManage) ...[
              const SizedBox(height: 20),
              const _SectionLabel('관리'),
              SoriCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _MenuTile(
                      icon: Icons.storefront_outlined,
                      title: '샵 정보',
                      onTap: () => _openShopSettings(context),
                    ),
                    if (isDirector) ...[
                      const Divider(height: 1),
                      _MenuTile(
                        icon: Icons.people_outline_rounded,
                        title: '고객 정보',
                        onTap: () => onSelectTab?.call(1),
                      ),
                    ],
                    const Divider(height: 1),
                    _MenuTile(
                      icon: Icons.spa_outlined,
                      title: '서비스 메뉴',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ServiceMenuPage(),
                          ),
                        );
                      },
                    ),
                    if (isDirector) ...[
                      const Divider(height: 1),
                      _MenuTile(
                        icon: Icons.photo_library_outlined,
                        title: '성공 사례',
                        onTap: () => onSelectTab?.call(3),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (isDirector) ...[
              const SizedBox(height: 20),
              const _SectionLabel('리뷰 통계'),
              _DirectorStatsDashboard(store: store),
              const SizedBox(height: 12),
              SoriCard(
                onTap: () => showShopReviewQrModal(context, store: store),
                child: const Row(
                  children: [
                    Icon(Icons.qr_code_2_rounded, color: SoriTokens.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '고객 리뷰 QR 생성/다운로드',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '샵 전용 리뷰 작성 페이지로 바로 연결돼요',
                            style: TextStyle(
                              fontSize: 12,
                              color: SoriTokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: SoriTokens.textSecondary),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const _SectionLabel('📊 AI 샵 경영 리포트'),
              const _AiShopReportCard(),
            ],
            const SizedBox(height: 20),
            const _SectionLabel('계정 / 설정'),
            SoriCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (session.canToggleMode) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.swap_horiz_rounded,
                            color: SoriTokens.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isDirector ? '원장 모드' : '고객 모드',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
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
                    const Divider(height: 1),
                  ],
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
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SoriCard(
      onTap: onTap,
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

class _DirectorStatsDashboard extends StatefulWidget {
  const _DirectorStatsDashboard({required this.store});

  final SoriStore store;

  @override
  State<_DirectorStatsDashboard> createState() =>
      _DirectorStatsDashboardState();
}

class _DirectorStatsDashboardState extends State<_DirectorStatsDashboard> {
  ReviewStatsPeriod _period = ReviewStatsPeriod.month;

  @override
  Widget build(BuildContext context) {
    final stats = DirectorPeriodStats.fromStore(
      widget.store,
      period: _period,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoriCard(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: SegmentedButton<ReviewStatsPeriod>(
            segments: const [
              ButtonSegment(
                value: ReviewStatsPeriod.year,
                label: Text('년'),
              ),
              ButtonSegment(
                value: ReviewStatsPeriod.month,
                label: Text('월'),
              ),
              ButtonSegment(
                value: ReviewStatsPeriod.week,
                label: Text('주'),
              ),
              ButtonSegment(
                value: ReviewStatsPeriod.day,
                label: Text('일'),
              ),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStateProperty.all(
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricFloatingCard(
                label: '작성된 리뷰',
                value: '${stats.reviewsWritten}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricFloatingCard(
                label: '네이버 전환율',
                value: '${stats.naverConversionPercent.toStringAsFixed(0)}%',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricFloatingCard(
                label: '차트 작성(케어)',
                value: '${stats.chartsWritten}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SoriCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '가장 많이 선택된 감성 칩 Top 3',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SoriTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              if (stats.topChips.isEmpty)
                Text(
                  '아직 집계할 칩 데이터가 없어요',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                )
              else
                ...stats.topChips.asMap().entries.map((e) {
                  final rank = e.key + 1;
                  final item = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: SoriTokens.primarySoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$rank',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: SoriTokens.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.chip,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${item.count}회',
                          style: const TextStyle(
                            fontSize: 12,
                            color: SoriTokens.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricFloatingCard extends StatelessWidget {
  const _MetricFloatingCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SoriCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: SoriTokens.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: SoriTokens.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.25,
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
        color: const Color(0xFFF3F4F6),
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
