import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../views/admin_chart_writer_page.dart';
import '../../visit_kernel/models/visit_session.dart';
import '../../visit_kernel/visit_store.dart';
import 'ba_recall_cache.dart';
import 'consultation_track.dart';
import 'visit_existing_customer_picker_page.dart';
import 'visit_new_customer_form_page.dart';
import 'visit_session_page.dart';

/// 상담 Home — Two-Track 진입 (신규 / 기존) + 오늘 대기열.
class VisitLauncherPage extends StatefulWidget {
  const VisitLauncherPage({super.key, required this.store});

  final SoriStore store;

  @override
  State<VisitLauncherPage> createState() => _VisitLauncherPageState();
}

class _VisitLauncherPageState extends State<VisitLauncherPage> {
  bool _loading = true;

  VisitStore get visit => widget.store.visit;

  static const _groupedBg = Color(0xFFF2F2F7);

  @override
  void initState() {
    super.initState();
    visit.addListener(_onVisit);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    visit.removeListener(_onVisit);
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _loading = true);
    await visit.ensureLoaded(force: force);
    if (mounted) setState(() => _loading = false);
  }

  void _onVisit() {
    if (mounted) setState(() {});
  }

  bool _hasPriorCharts(String customerId, {String? excludeChartId}) {
    return widget.store
        .chartsForCustomer(customerId)
        .any((c) => c.id != excludeChartId);
  }

  ConsultationTrack _trackForCustomer(String customerId, {String? chartId}) {
    return _hasPriorCharts(customerId, excludeChartId: chartId)
        ? ConsultationTrack.returning
        : ConsultationTrack.newCustomer;
  }

  Future<void> _startNewCustomerFlow() async {
    final customer = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(
        builder: (_) => VisitNewCustomerFormPage(store: widget.store),
      ),
    );
    if (customer == null || !mounted) return;
    await _startSessionFor(customer, ConsultationTrack.newCustomer);
  }

  Future<void> _startReturningCustomerFlow() async {
    final customer = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(
        builder: (_) =>
            VisitExistingCustomerPickerPage(store: widget.store),
      ),
    );
    if (customer == null || !mounted) return;

    unawaited(
      BaRecallCache.instance.prefetch(
        widget.store,
        customer.id,
        imageContext: context,
      ),
    );
    await _startSessionFor(customer, ConsultationTrack.returning);
  }

  Future<void> _startSessionFor(
    Customer customer,
    ConsultationTrack track,
  ) async {
    try {
      final session = await visit.startVisit(customer);
      if (!mounted) return;
      await _openSession(session, track);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상담 시작 실패: $e')),
      );
    }
  }

  Future<void> _openQuickChart() async {
    final customer = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(
        builder: (_) =>
            VisitExistingCustomerPickerPage(store: widget.store),
      ),
    );
    if (customer == null || !mounted) return;
    await openChartWriterForCustomer(
      context,
      store: widget.store,
      customer: customer,
      forceQuickChart: true,
    );
    if (mounted) await _load(force: true);
  }

  Future<void> _openSession(
    VisitSession session,
    ConsultationTrack track,
  ) async {
    if (track == ConsultationTrack.returning) {
      unawaited(
        BaRecallCache.instance.prefetch(
          widget.store,
          session.customerId,
          imageContext: context,
        ),
      );
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisitSessionPage(
          store: widget.store,
          sessionId: session.id,
          track: track,
        ),
      ),
    );
    await _load(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final snap = visit.snapshotForDay(day);
    final sessions = snap.sessions;

    return ColoredBox(
      color: _groupedBg,
      child: RefreshIndicator(
        color: SoriTokens.primary,
        onRefresh: () => _load(force: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text(
                  '상담',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w300,
                    height: 1.1,
                    color: SoriTokens.textPrimary.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  '신규·기존 고객에 맞는 상담 시트를 선택하세요',
                  style: TextStyle(
                    fontSize: 15,
                    color: SoriTokens.textSecondary.withValues(alpha: 0.95),
                    height: 1.35,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= 560;
                    final newCard = _TrackEntryCard(
                      title: '신규 고객 상담',
                      subtitle: '첫 방문 · Before 촬영 · 동의서',
                      icon: Icons.person_add_alt_1_rounded,
                      onTap: _startNewCustomerFlow,
                    );
                    final returningCard = _TrackEntryCard(
                      title: '기존 고객 상담',
                      subtitle: 'B/A 회상 · 직전 계획 · 재방문',
                      icon: Icons.history_rounded,
                      emphasized: true,
                      onTap: _startReturningCustomerFlow,
                    );
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: newCard),
                          const SizedBox(width: 12),
                          Expanded(child: returningCard),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        newCard,
                        const SizedBox(height: 12),
                        returningCard,
                      ],
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _openQuickChart,
                    icon: const Icon(Icons.bolt_rounded, size: 16),
                    label: const Text('간편 기록만'),
                  ),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (sessions.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                  child: Text(
                    '오늘 진행 중 · ${sessions.length}명',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final session = sessions[i];
                    final chart =
                        widget.store.chartForVisitSession(session);
                    final track = _trackForCustomer(
                      session.customerId,
                      chartId: chart?.id,
                    );
                    return _ConsultQueueRow(
                      session: session,
                      store: widget.store,
                      isReturning: track == ConsultationTrack.returning,
                      onTap: () => _openSession(session, track),
                    );
                  },
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

class _TrackEntryCard extends StatelessWidget {
  const _TrackEntryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.emphasized = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized ? SoriTokens.primary : SoriTokens.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: emphasized ? SoriTokens.primary : SoriTokens.border,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: emphasized ? SoriTokens.onPrimary : SoriTokens.textPrimary,
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: emphasized
                        ? SoriTokens.onPrimary
                        : SoriTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: emphasized
                        ? SoriTokens.onPrimary.withValues(alpha: 0.85)
                        : SoriTokens.textSecondary,
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

class _ConsultQueueRow extends StatelessWidget {
  const _ConsultQueueRow({
    required this.session,
    required this.store,
    required this.onTap,
    required this.isReturning,
  });

  final VisitSession session;
  final SoriStore store;
  final VoidCallback onTap;
  final bool isReturning;

  @override
  Widget build(BuildContext context) {
    final chart = store.chartForVisitSession(session);
    final visitNo = chart?.visitNumber;
    final phaseLabel = session.phase.label;

    return Material(
      color: Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SoriTokens.border.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: SoriTokens.surface,
                child: Text(
                  session.customerName.characters.first,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.customerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        isReturning ? '재방문' : '신규',
                        if (visitNo != null) '${visitNo}회차',
                        phaseLabel,
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: SoriTokens.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SoriTokens.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SoriTokens.border),
                ),
                child: Text(
                  phaseLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: SoriTokens.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: SoriTokens.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
