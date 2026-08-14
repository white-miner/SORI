import 'package:flutter/material.dart';

import '../models/ai_shop_report_mock.dart';
import '../models/customer_chart.dart';
import '../models/session_user.dart';
import '../services/director_stats.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/membership_ticket_wallet.dart';
import '../widgets/sori_logo.dart';
import 'ai_shop_report_page.dart';
import 'customer_review_history_page.dart';
import 'director_profile_edit_page.dart';
import 'my_info_edit_page.dart';

/// 마이페이지 전용 쿨그레이 배경.
const Color _myPageBg = Color(0xFFF5F6F8);
const Color _mutedText = Color(0xFF757575);

class MyPage extends StatefulWidget {
  const MyPage({
    super.key,
    required this.store,
    this.onSelectTab,
  });

  final SoriStore store;
  final ValueChanged<int>? onSelectTab;

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  SoriStore get store => widget.store;
  ValueChanged<int>? get onSelectTab => widget.onSelectTab;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshMembershipWallet();
    });
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final session = store.session;
    if (session == null) return const SizedBox.shrink();

    if (session.activeMode == UserRole.director) {
      return _DirectorVisualMyPage(
        store: store,
        onSelectTab: onSelectTab,
      );
    }
    return _CustomerMyPage(
      store: store,
      session: session,
    );
  }
}

/// 원장 모드 — Instagram형 시각적 프로필 대시보드.
class _DirectorVisualMyPage extends StatelessWidget {
  const _DirectorVisualMyPage({
    required this.store,
    this.onSelectTab,
  });

  final SoriStore store;
  final ValueChanged<int>? onSelectTab;

  List<CustomerChart> get _baCases {
    final out = <CustomerChart>[];
    for (final chart in store.charts) {
      final b = chart.beforeImageUrl?.trim() ?? '';
      final a = chart.afterImageUrl?.trim() ?? '';
      if (b.isEmpty && a.isEmpty) continue;
      final shopId = store.shop.id;
      if (chart.shopId.isNotEmpty &&
          shopId.isNotEmpty &&
          chart.shopId != shopId) {
        continue;
      }
      out.add(chart);
    }
    out.sort((a, b) {
      final ad = a.visitCheckedAt ??
          a.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.visitCheckedAt ??
          b.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return out;
  }

  String get _bio {
    final shop = store.shop;
    final tip = store.todayHomecareTip.trim();
    final hours = shop.operatingHours.trim();
    final parts = <String>[];
    if (tip.isNotEmpty) parts.add(tip);
    if (hours.isNotEmpty) parts.add('영업 $hours');
    if (shop.address != null && shop.address!.trim().isNotEmpty) {
      parts.add(shop.address!.trim());
    }
    if (parts.isEmpty) {
      return '샵 소개와 영업시간을 프로필 편집에서 등록해 주세요.';
    }
    return parts.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final shop = store.shop;
    final shopName = shop.name.trim().isEmpty ? 'SORI' : shop.name.trim();
    final owner = (shop.ownerName ?? '').trim();
    final ownerLabel = owner.isEmpty
        ? '원장'
        : (owner.contains('원장') ? owner : '$owner 원장');
    final reviewCount = store.reviews
        .where(DirectorPeriodStats.isCompletedReview)
        .length;
    final chartCount = store.charts.length;
    final cases = _baCases;

    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B7CFF), Color(0xFF4A3BCF)],
                            ),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    SoriTokens.primary.withValues(alpha: 0.22),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(18),
                            child: SoriLogo(width: 50, height: 50),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _ProfileStat(
                                  value: '$reviewCount',
                                  label: '소통 리뷰',
                                ),
                              ),
                              Expanded(
                                child: _ProfileStat(
                                  value: '${store.customers.length}',
                                  label: '등록 고객',
                                  onTap: () => onSelectTab?.call(1),
                                ),
                              ),
                              Expanded(
                                child: _ProfileStat(
                                  value: '$chartCount',
                                  label: '차트 작성',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      shopName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ownerLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _bio,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: SoriTokens.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const DirectorProfileEditPage(),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEEF2F7),
                          foregroundColor: SoriTokens.textPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '프로필 편집',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AiReportSummaryCard(
                      report: AiShopReportMock.demo(),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '내 샵 관리 케이스',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => onSelectTab?.call(3),
                          child: const Text(
                            '전체 보기',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: SoriTokens.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (cases.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Text(
                      '등록된 B/A 케이스를 준비 중입니다 ✨\n차트에 Before/After를 남기면 여기에 모여요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: SoriTokens.textSecondary,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(2, 0, 2, 88),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                    childAspectRatio: 1,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final chart = cases[index];
                      final after = chart.afterImageUrl?.trim() ?? '';
                      final before = chart.beforeImageUrl?.trim() ?? '';
                      final url = after.isNotEmpty ? after : before;
                      return Material(
                        color: const Color(0xFFF0F1F3),
                        child: InkWell(
                          onTap: () => onSelectTab?.call(3),
                          child: url.isEmpty
                              ? const Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: Colors.grey,
                                  ),
                                )
                              : Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  filterQuality: FilterQuality.low,
                                  errorBuilder: (_, _, _) => const Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                        ),
                      );
                    },
                    childCount: cases.length,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.value,
    required this.label,
    this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: child,
      ),
    );
  }
}

class _AiReportSummaryCard extends StatelessWidget {
  const _AiReportSummaryCard({required this.report});

  final AiShopReportMock report;

  String get _salesLabel {
    final won = report.revenue.estimatedSalesWon;
    if (won >= 100000000) {
      return '${(won / 100000000).toStringAsFixed(1)}억';
    }
    if (won >= 10000) {
      final man = (won / 10000).round();
      return '${_comma(man)}만원';
    }
    return '${_comma(won)}원';
  }

  String _comma(int n) {
    final s = '$n';
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final recommend = report.portfolio.investMenus.isNotEmpty
        ? report.portfolio.investMenus.first.name
        : '추천 메뉴 분석 중';
    final delta = report.revenue.salesDeltaPercent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AiShopReportPage(data: report),
            ),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1F2937), Color(0xFF374151)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text(
                              'AI 리포트',
                              style: TextStyle(
                                color: Color(0xFF34D399),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            report.periodLabel,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'AI 샵 경영 리포트',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryMetric(
                              label: '추정 매출',
                              value: _salesLabel,
                              hint: delta >= 0
                                  ? '+${delta.toStringAsFixed(1)}%'
                                  : '${delta.toStringAsFixed(1)}%',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: Colors.white24,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: _SummaryMetric(
                                label: '이번 달 추천',
                                value: recommend,
                                hint: '투자 메뉴',
                                compact: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.hint,
    this.compact = false,
  });

  final String label;
  final String value;
  final String hint;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 13 : 18,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          hint,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// 고객 모드 마이 — 지갑·리뷰 중심 (시스템 설정은 ⚙️).
class _CustomerMyPage extends StatelessWidget {
  const _CustomerMyPage({
    required this.store,
    required this.session,
  });

  final SoriStore store;
  final SessionUser session;

  @override
  Widget build(BuildContext context) {
    final customerId = session.customerId;
    final charts = customerId == null
        ? store.charts
        : store.chartsForCustomer(customerId);
    final reviewCount = charts.where((c) {
      final r = store.reviewForChart(c.id);
      return r != null && DirectorPeriodStats.isCompletedReview(r);
    }).length;
    final wallet = store.activeMembershipWallet;
    final remain = wallet.fold<int>(0, (s, t) => s + t.remainingVisits);
    final displayName =
        session.name.trim().isEmpty ? '고객' : session.name.trim();

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
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MyInfoEditPage(),
                        ),
                      );
                    },
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
                      '프로필',
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
                    onTap: () {
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
                    child: _MiniStat(
                      label: '보유 티켓',
                      value: '${wallet.length}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '스마트 회원권 지갑',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (remain > 0)
                  Text(
                    '잔여 합계 $remain회',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6C5CE7),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            MembershipTicketWallet(
              tickets: wallet,
              onRefresh: store.refreshMembershipWallet,
            ),
            const SizedBox(height: 16),
            Text(
              '모드 전환 · 로그아웃은 상단 ⚙️ 설정에서 관리합니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
