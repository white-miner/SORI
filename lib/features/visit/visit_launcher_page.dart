import 'package:flutter/material.dart';

import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../views/admin_chart_writer_page.dart';
import '../../visit_kernel/models/visit_session.dart';
import '../../visit_kernel/theme/visit_glass_tokens.dart';
import '../../visit_kernel/visit_store.dart';
import 'visit_customer_picker_sheet.dart';
import 'visit_session_page.dart';

/// 상담 Home — CDG list queue (PRD v3.1).
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

  Future<void> _startConsultation() async {
    final customer = await showVisitCustomerPickerSheet(
      context,
      store: widget.store,
    );
    if (customer == null || !mounted) return;

    try {
      final session = await visit.startVisit(customer);
      if (!mounted) return;
      await _openSession(session);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상담 시작 실패: $e')),
      );
    }
  }

  Future<void> _openQuickChart() async {
    final customer = await showVisitCustomerPickerSheet(
      context,
      store: widget.store,
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

  Future<void> _openSession(VisitSession session) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisitSessionPage(
          store: widget.store,
          sessionId: session.id,
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
      child: Stack(
        children: [
          RefreshIndicator(
            color: VisitGlassTokens.care,
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
                      sessions.isEmpty
                          ? '오늘 함께할 상담을 시작해 보세요'
                          : '오늘 ${sessions.length}명과 함께할 시간',
                      style: VisitGlassTokens.bodyCalm.copyWith(
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ),
                ),
                if (_loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (sessions.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Text(
                        '손님을 맞이하면 「상담 시작」을 눌러 주세요.',
                        style: VisitGlassTokens.captionCalm.copyWith(
                          color: SoriTokens.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(
                      itemCount: sessions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final session = sessions[i];
                        return _ConsultQueueRow(
                          session: session,
                          store: widget.store,
                          onTap: () => _openSession(session),
                        );
                      },
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ConsultationActionBar(
              onStart: _startConsultation,
              onQuickChart: _openQuickChart,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsultationActionBar extends StatelessWidget {
  const _ConsultationActionBar({
    required this.onStart,
    required this.onQuickChart,
  });

  final VoidCallback onStart;
  final VoidCallback onQuickChart;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          10 + MediaQuery.paddingOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7).withValues(alpha: 0.95),
          border: Border(
            top: BorderSide(color: SoriTokens.border.withValues(alpha: 0.35)),
          ),
        ),
        child: Row(
          children: [
            OutlinedButton(
              onPressed: onQuickChart,
              child: const Text('+ 간편 기록'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  backgroundColor: VisitGlassTokens.care,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('상담 시작'),
              ),
            ),
          ],
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
  });

  final VisitSession session;
  final SoriStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chart = store.chartForVisitSession(session);
    final visitNo = chart?.visitNumber;
    final phaseLabel = session.phase.label;

    return Material(
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SoriTokens.border.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: VisitGlassTokens.care.withValues(alpha: 0.12),
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
                        if (visitNo != null) '${visitNo}회차',
                        phaseLabel,
                      ].join(' · '),
                      style: VisitGlassTokens.captionCalm.copyWith(
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: VisitGlassTokens.care.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  phaseLabel,
                  style: VisitGlassTokens.captionCalm.copyWith(
                    color: VisitGlassTokens.care,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: SoriTokens.textSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
