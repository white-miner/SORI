import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../routing/sori_router.dart';
import '../services/customer_crm_status_resolver.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/sori_crm_status_avatar.dart';
import 'admin_chart_writer_page.dart';
import 'before_after_compare_page.dart';
import 'chart_management_page.dart';
import 'customer_merge_wizard.dart';
import 'membership_editor_sheet.dart';
import 'request_customer_review.dart';

/// 원장용: 회차 다이렉트 리스트 + Before/After 갤러리.
class AdminChartPage extends StatefulWidget {
  const AdminChartPage({
    super.key,
    required this.store,
    required this.customerId,
  });

  final SoriStore store;
  final String customerId;

  @override
  State<AdminChartPage> createState() => _AdminChartPageState();
}

class _AdminChartPageState extends State<AdminChartPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    widget.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Customer? get _customer => widget.store.findCustomer(widget.customerId);

  List<CustomerChart> get _timeline =>
      widget.store.chartsForCustomer(widget.customerId);

  Future<void> _openChartManagement({String? chartId}) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ChartManagementPage(
          store: widget.store,
          customerId: widget.customerId,
          initialChartId: chartId,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openWriter({
    CustomerChart? chart,
    bool forceQuickChart = false,
  }) async {
    final customer = _customer;
    if (customer == null) return;
    await openChartWriterForCustomer(
      context,
      store: widget.store,
      customer: customer,
      existingChart: chart,
      forceQuickChart: forceQuickChart,
    );
    // Store 리스너가 타임라인을 갱신하지만, 복귀 직후 한 번 더 보장.
    if (mounted) setState(() {});
  }

  Future<void> _openMembershipSheet() async {
    final customer = _customer;
    if (customer == null) return;
    final result = await showMembershipEditorSheet(
      context: context,
      store: widget.store,
      customer: customer,
      persistImmediately: true,
    );
    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isEmpty
              ? '회원권을 비웠습니다'
              : '회원권 ${result.length}종이 저장됐어요',
        ),
        backgroundColor: SoriTokens.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openBeforeAfterCompare() async {
    final customer = _customer;
    if (customer == null) return;
    await openBeforeAfterComparePage(
      context: context,
      customerName: customer.name,
      charts: _timeline,
      initialChartId: _timeline.isEmpty ? null : _timeline.first.id,
      initialCareName: _timeline.isEmpty ? null : _timeline.first.careName,
      customerId: customer.id,
      store: widget.store,
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;
    if (customer == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('차트 관리'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppPaths.appCustomers);
              }
            },
          ),
        ),
        body: const Center(child: Text('고객 정보를 찾을 수 없습니다.')),
      );
    }

    final timeline = _timeline;

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: Text(customer.name),
        backgroundColor: SoriTokens.surface,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppPaths.appCustomers);
            }
          },
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: '더보기',
            onSelected: (value) async {
              if (value == 'merge') {
                final selected = await pickCustomersForMerge(
                  context: context,
                  store: widget.store,
                  seed: customer,
                );
                if (selected != null && selected.length >= 2 && context.mounted) {
                  await showCustomerMergeWizard(
                    context: context,
                    store: widget.store,
                    selected: selected,
                  );
                }
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'merge',
                child: Text('중복 계정 병합'),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: () => requestCustomerReviewWithQr(
              context,
              store: widget.store,
              customer: customer,
            ),
            icon: const Icon(Icons.qr_code_2_rounded, size: 18),
            label: const Text(
              '후기 요청',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      body: PrimaryScrollController(
        controller: _scrollController,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _Header(
                  customer: customer,
                  charts: timeline,
                  lastVisitLabel: timeline.isEmpty
                      ? null
                      : _formatChartDate(timeline.first),
                  onTap: () =>
                      context.push(AppPaths.customerProfile(customer.id)),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: _QuickActionDashboard(
                  onMembership: _openMembershipSheet,
                  onQuickChart: () => _openWriter(forceQuickChart: true),
                  onChartManage: _openChartManagement,
                  onBeforeAfter: _openBeforeAfterCompare,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

String _formatChartDate(CustomerChart chart) {
  final dt = chart.visitCheckedAt ?? chart.feedbackLineOpenedAt ?? chart.createdAt;
  if (dt == null) return '날짜 미정';
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y.$m.$d';
}

class _Header extends StatelessWidget {
  const _Header({
    required this.customer,
    required this.charts,
    required this.onTap,
    this.lastVisitLabel,
  });

  final Customer customer;
  final List<CustomerChart> charts;
  final VoidCallback onTap;
  final String? lastVisitLabel;

  @override
  Widget build(BuildContext context) {
    final ringVisual = CustomerCrmStatusResolver.resolve(customer, charts);

    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: SoriTokens.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                SoriCrmStatusAvatar(
                  name: customer.name,
                  visual: ringVisual,
                  radius: 24,
                  fontSize: 18,
                  animateWhenVisible: true,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.nameWithAge,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customer.phone,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (customer.isMembershipCustomer) ...[
                        const SizedBox(height: 6),
                        Text(
                          customer.membershipBadgeLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                      if (lastVisitLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '최근 방문: $lastVisitLabel',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionDashboard extends StatelessWidget {
  const _QuickActionDashboard({
    required this.onMembership,
    required this.onQuickChart,
    required this.onChartManage,
    required this.onBeforeAfter,
  });

  final VoidCallback onMembership;
  final VoidCallback onQuickChart;
  final VoidCallback onChartManage;
  final VoidCallback onBeforeAfter;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _BentoCard(
                title: '1초 간편 차트',
                subtitle: '신규 회차 작성',
                icon: Icons.bolt_rounded,
                iconBg: const Color(0xFFF4F4F5),
                iconFg: const Color(0xFF111111),
                onTap: onQuickChart,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BentoCard(
                title: '차트 관리',
                subtitle: '열람 · 수정',
                icon: Icons.folder_open_rounded,
                iconBg: const Color(0xFFF4F4F5),
                iconFg: const Color(0xFF111111),
                onTap: onChartManage,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _BentoCard(
                title: '회원권 관리',
                subtitle: '등록·수정',
                icon: Icons.card_membership_rounded,
                iconBg: const Color(0xFFE5E5EA),
                iconFg: const Color(0xFF111111),
                onTap: onMembership,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BentoCard(
                title: 'B/A 비교',
                subtitle: '경과 보기',
                icon: Icons.compare_rounded,
                iconBg: const Color(0xFFE5E5EA),
                iconFg: const Color(0xFF111111),
                onTap: onBeforeAfter,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BentoCard extends StatelessWidget {
  const _BentoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: SoriTokens.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.045),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _QuickIcon(
                  icon: icon,
                  bg: iconBg,
                  fg: iconFg,
                  size: 42,
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: SoriTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickIcon extends StatelessWidget {
  const _QuickIcon({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.size,
  });

  final IconData icon;
  final Color bg;
  final Color fg;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: fg, size: size * 0.46),
    );
  }
}

