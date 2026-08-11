import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/session_user.dart';
import '../routing/app_router.dart';
import '../services/director_stats.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/membership_progress.dart';
import '../widgets/review_qr_modal.dart';
import '../widgets/sori_logo.dart';
import 'customer_review_history_page.dart';
import 'my_info_edit_page.dart';
import 'service_menu_page.dart';
import 'shop_settings_page.dart';

/// 마이페이지 전용 쿨그레이 배경.
const Color _myPageBg = Color(0xFFF5F6F8);
const Color _mutedText = Color(0xFF757575); // grey[600]

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
  }

  @override
  Widget build(BuildContext context) {
    final session = store.session!;
    final customerId = session.customerId;
    final charts = customerId == null
        ? store.charts
        : store.chartsForCustomer(customerId);
    final reviewCount =
        charts.where((c) => store.reviewForChart(c.id) != null).length;
    final customer =
        customerId == null ? null : store.findCustomer(customerId);
    final remain = customer?.membershipRemainingVisits ?? 0;

    final isDirector = session.activeMode == UserRole.director;
    final shop = store.shop;
    final shopName = shop.name.trim();
    final ownerName = (shop.ownerName ?? '').trim();
    final hasShopProfile = shopName.isNotEmpty && ownerName.isNotEmpty;
    final displayName = isDirector
        ? (hasShopProfile
            ? '$shopName / 원장 $ownerName'
            : (session.name.trim().isEmpty ? '원장' : session.name))
        : (session.name.trim().isEmpty ? '고객' : session.name);

    Future<void> openProfileEdit() async {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const MyInfoEditPage()),
      );
    }

    return ColoredBox(
      color: _myPageBg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            _FloatCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: SoriTokens.primarySoft,
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Opacity(
                        opacity: 0.85,
                        child: SoriLogo(width: 36, height: 36),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${session.phone} · ${session.providerLabel}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: _mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: openProfileEdit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SoriTokens.primary,
                      side: const BorderSide(color: SoriTokens.primary),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      '프로필 관리',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _FloatCard(
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
                    child: _MiniStat(
                      label: '내 소통 리뷰',
                      value: '$reviewCount',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FloatCard(
                    onTap: () => onSelectTab?.call(1),
                    child: _MiniStat(
                      label: isDirector ? '등록 고객' : '회원권 남은 회차',
                      value: isDirector
                          ? '${store.customers.length}'
                          : '$remain',
                    ),
                  ),
                ),
              ],
            ),
            if (!isDirector && customer != null) ...[
              const SizedBox(height: 12),
              _FloatCard(
                child: MembershipProgressView(customer: customer),
              ),
            ],
            // 원장 전용 관리 / 통계 영역 (고객 모드에서는 완전 숨김)
            if (isDirector) ...[
              const SizedBox(height: 28),
              const _SectionTitle('관리'),
              _FloatCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    _MenuTile(
                      icon: Icons.storefront_outlined,
                      title: '샵 정보',
                      onTap: () => _openShopSettings(context),
                    ),
                    const SizedBox(height: 4),
                    _MenuTile(
                      icon: Icons.people_outline_rounded,
                      title: '고객 정보',
                      onTap: () => onSelectTab?.call(1),
                    ),
                    const SizedBox(height: 4),
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
                    const SizedBox(height: 4),
                    _MenuTile(
                      icon: Icons.photo_library_outlined,
                      title: '관리 케이스',
                      onTap: () => onSelectTab?.call(3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const _SectionTitle('리뷰 통계'),
              _DirectorStatsDashboard(store: store),
              const SizedBox(height: 12),
              _FloatCard(
                onTap: () => showShopReviewQrModal(context, store: store),
                child: Row(
                  children: [
                    const Icon(
                      Icons.qr_code_2_rounded,
                      color: SoriTokens.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '고객 리뷰 QR 생성/다운로드',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '샵 전용 리뷰 작성 페이지로 바로 연결돼요',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const _SectionTitle('AI 샵 경영 리포트'),
              const _AiShopReportCard(),
            ],
            const SizedBox(height: 28),
            const _SectionTitle('계정 / 설정'),
            _FloatCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  if (session.canToggleMode) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
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
                    const SizedBox(height: 4),
                  ],
                  _MenuTile(
                    icon: Icons.manage_accounts_outlined,
                    title: '프로필 관리',
                    onTap: openProfileEdit,
                  ),
                  const SizedBox(height: 4),
                  _MenuTile(
                    icon: Icons.help_outline,
                    title: '고객센터',
                    onTap: () {},
                  ),
                  const SizedBox(height: 4),
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

/// 순백색 플로팅 카드 (radius 16 + 옅은 넓은 그림자).
class _FloatCard extends StatelessWidget {
  const _FloatCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  static final List<BoxShadow> _shadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 10,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _shadow,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Colors.grey[600],
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
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: SoriTokens.textPrimary,
          letterSpacing: -0.3,
        ),
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
        _FloatCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<ReviewStatsPeriod>(
              groupValue: _period,
              backgroundColor: const Color(0xFFF0F1F3),
              thumbColor: Colors.white,
              padding: const EdgeInsets.all(3),
              children: {
                ReviewStatsPeriod.week: _segLabel(
                  '일주일',
                  _period == ReviewStatsPeriod.week,
                ),
                ReviewStatsPeriod.month: _segLabel(
                  '월',
                  _period == ReviewStatsPeriod.month,
                ),
                ReviewStatsPeriod.year: _segLabel(
                  '년',
                  _period == ReviewStatsPeriod.year,
                ),
              },
              onValueChanged: (v) {
                if (v == null) return;
                setState(() => _period = v);
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _FloatCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                child: _MetricBlock(
                  label: '작성된 리뷰',
                  value: '${stats.reviewsWritten}',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FloatCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                child: _MetricBlock(
                  label: '네이버 전환율',
                  value:
                      '${stats.naverConversionPercent.toStringAsFixed(0)}%',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FloatCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                child: _MetricBlock(
                  label: '차트 작성(케어)',
                  value: '${stats.chartsWritten}',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _FloatCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '가장 많이 선택된 감성 칩 Top 3',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              if (stats.topChips.isEmpty)
                const _ChipsEmptyState()
              else
                ...stats.topChips.asMap().entries.map((e) {
                  final rank = e.key + 1;
                  final item = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: SoriTokens.primarySoft,
                            borderRadius: BorderRadius.circular(8),
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.chip,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          '${item.count}회',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
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

  Widget _segLabel(String text, bool selected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? SoriTokens.textPrimary : Colors.grey[600],
        ),
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
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
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w400,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _ChipsEmptyState extends StatelessWidget {
  const _ChipsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 52,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              '아직 집계할 칩 데이터가 없어요',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiShopReportCard extends StatelessWidget {
  const _AiShopReportCard();

  @override
  Widget build(BuildContext context) {
    return _FloatCard(
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI 샵 경영 리포트',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '고객 차트 · 후기 키워드를 분석했어요',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[600],
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
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[600],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: danger ? Colors.redAccent : SoriTokens.textPrimary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: danger ? Colors.redAccent : SoriTokens.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
