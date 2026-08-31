import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../views/admin_chart_page.dart';
import '../../views/admin_chart_writer_page.dart';
import '../../visit_kernel/models/visit_session.dart';
import '../../visit_kernel/theme/visit_glass_tokens.dart';
import '../../visit_kernel/visit_store.dart';
import '../operation/models/clinical_environment_brief.dart';
import '../operation/models/consultation_deep_mode.dart';
import '../operation/models/clinical_trend_snapshot.dart';
import '../operation/models/shop_climate_context.dart';
import '../operation/models/visit_biometrics.dart';
import '../operation/shop_climate_service.dart';
import '../operation/shop_clinical_trend_service.dart';
import '../operation/visit_timer_store.dart';
import '../operation/widgets/care_timer_widget.dart';
import '../operation/widgets/clinical_assistant_sheet.dart';
import '../operation/widgets/consultation_widget_board.dart';
import '../operation/widgets/sos_signal_bar.dart';
import '../operation/widgets/volume_glass_theme.dart';
import '../../views/smart_guide_camera_page.dart';
import 'ba_recall_cache.dart';
import 'consultation_briefing_sheet.dart';
import 'consultation_track.dart';
import 'today_agenda.dart';
import 'visit_existing_customer_picker_page.dart';
import 'visit_new_customer_form_page.dart';

/// 상담 Home — Pre-Consultation Dashboard (Sprint 3.3 + 4.5 timer).
class VisitLauncherPage extends StatefulWidget {
  const VisitLauncherPage({super.key, required this.store});

  final SoriStore store;

  @override
  State<VisitLauncherPage> createState() => _VisitLauncherPageState();
}

class _VisitLauncherPageState extends State<VisitLauncherPage> {
  bool _loading = true;
  ShopClimateContext? _climate;
  ClinicalTrendSnapshot? _trends;

  VisitStore get visit => widget.store.visit;

  static const _groupedBg = SoriTokens.background;

  @override
  void initState() {
    super.initState();
    visit.addListener(_onVisit);
    widget.store.addListener(_onVisit);
    VisitTimerStore.instance.addListener(_onVisit);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    visit.removeListener(_onVisit);
    widget.store.removeListener(_onVisit);
    VisitTimerStore.instance.removeListener(_onVisit);
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _loading = true);
    await Future.wait([
      visit.ensureLoaded(force: force),
      widget.store.refreshCareScheduleEntries(force: force),
      widget.store.hydrateVisitTimer(),
      _loadClimate(),
      _loadTrends(),
    ]);
    if (!mounted) return;
    _autoWarmNextCustomer();
    setState(() => _loading = false);
  }

  Future<void> _loadClimate() async {
    try {
      final ctx =
          await ShopClimateService.instance.fetchForShop(widget.store.shop);
      if (mounted) _climate = ctx;
    } catch (_) {
      if (mounted) {
        _climate = ShopClimateContext.fallback();
      }
    }
  }

  Future<void> _loadTrends() async {
    try {
      final snap = await ShopClinicalTrendService.instance
          .fetchForShop(widget.store.shop);
      if (mounted) _trends = snap;
    } catch (_) {
      if (mounted) _trends = ClinicalTrendSnapshot.fallback();
    }
  }

  void _openClinicalSheet({ClinicalTrendItem? trend}) {
    final climate = _climate;
    if (climate == null) return;
    final snap = _agendaSnapshot();
    unawaited(
      showClinicalAssistantSheet(
        context: context,
        climate: climate,
        trends: _trends,
        initialTrend: trend,
        tempoLevel: computeTempoLevel(
          scheduledCount: snap.scheduledCount,
          inProgressCount: snap.inProgressCount,
        ),
      ),
    );
  }

  void _onVisit() {
    if (mounted) setState(() {});
  }

  TodayAgendaSnapshot _agendaSnapshot() {
    final now = DateTime.now();
    return buildTodayAgenda(
      store: widget.store,
      now: now,
      schedules: widget.store.careScheduleEntries,
      sessions: visit.sessions,
      sosParser: widget.store.sosParser,
    );
  }

  void _autoWarmNextCustomer() {
    final snap = _agendaSnapshot();
    final next = snap.items.where((e) => e.isNext).firstOrNull ??
        snap.items.where((e) => e.isReturning && !e.hasActiveSession).firstOrNull;
    final cid = next?.customerId.trim() ?? '';
    if (cid.isEmpty || !next!.isReturning) return;
    unawaited(
      BaRecallCache.instance.prefetch(
        widget.store,
        cid,
        imageContext: context,
      ),
    );
  }

  Future<void> _openBriefing(TodayAgendaItem item) async {
    final briefing = buildConsultationBriefing(widget.store, item);
    await showConsultationBriefingSheet(
      context: context,
      briefing: briefing,
      onStartConsultation: (biometrics) =>
          _startFromBriefing(item, biometrics: biometrics),
      onOpenCustomerDetail: item.customerId.trim().isEmpty
          ? null
          : () => _openCustomerDetail(item.customerId),
    );
  }

  void _openCustomerDetail(String customerId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminChartPage(
          store: widget.store,
          customerId: customerId,
        ),
      ),
    );
  }

  Future<void> _startFromBriefing(
    TodayAgendaItem item, {
    required VisitBiometrics biometrics,
  }) async {
    final briefing = buildConsultationBriefing(
      widget.store,
      item,
      biometricsOverride: biometrics,
    );

    if (item.hasActiveSession && item.session != null) {
      final chart = widget.store.chartForVisitSession(item.session!);
      if (chart != null) {
        await widget.store.persistVisitBiometrics(
          chartId: chart.id,
          biometrics: biometrics,
        );
      }
      await _beginConsultation(item.session!);
      return;
    }

    Customer? customer;
    if (item.customerId.trim().isNotEmpty) {
      customer = widget.store.findCustomer(item.customerId);
    }

    if (customer == null) {
      if (item.track == ConsultationTrack.returning) {
        await _startReturningCustomerFlow(
          deepMode: briefing.deepMode,
          biometrics: biometrics,
          environmentBrief: briefing.environmentBrief,
        );
      } else {
        await _startNewCustomerFlow(
          prefillName: item.customerName,
          deepMode: briefing.deepMode,
          biometrics: biometrics,
          environmentBrief: briefing.environmentBrief,
        );
      }
      return;
    }

    if (item.track == ConsultationTrack.returning) {
      unawaited(
        BaRecallCache.instance.prefetch(
          widget.store,
          customer.id,
          imageContext: context,
        ),
      );
    }
    await _startSessionFor(
      customer,
      item.track,
      deepMode: briefing.deepMode,
      biometrics: biometrics,
      environmentBrief: briefing.environmentBrief,
    );
    final session = widget.store.activeVisitSession;
    if (session != null) await _beginConsultation(session);
  }

  Future<void> _startNewCustomerFlow({
    String? prefillName,
    ConsultationDeepMode? deepMode,
    VisitBiometrics? biometrics,
    ClinicalEnvironmentBrief? environmentBrief,
  }) async {
    final customer = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(
        builder: (_) => VisitNewCustomerFormPage(
          store: widget.store,
          initialName: prefillName,
        ),
      ),
    );
    if (customer == null || !mounted) return;
    await _startSessionFor(
      customer,
      ConsultationTrack.newCustomer,
      deepMode: deepMode,
      biometrics: biometrics,
      environmentBrief: environmentBrief,
    );
  }

  Future<void> _startReturningCustomerFlow({
    ConsultationDeepMode? deepMode,
    VisitBiometrics? biometrics,
    ClinicalEnvironmentBrief? environmentBrief,
  }) async {
    final customer = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(
        builder: (_) => VisitExistingCustomerPickerPage(store: widget.store),
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
    await _startSessionFor(
      customer,
      ConsultationTrack.returning,
      deepMode: deepMode,
      biometrics: biometrics,
      environmentBrief: environmentBrief,
    );
  }

  Future<void> _startSessionFor(
    Customer customer,
    ConsultationTrack track, {
    ConsultationDeepMode? deepMode,
    VisitBiometrics? biometrics,
    ClinicalEnvironmentBrief? environmentBrief,
  }) async {
    try {
      final session = await visit.startVisit(customer);
      if (!mounted) return;
      final chart = widget.store.chartForVisitSession(session);
      if (chart != null && biometrics != null) {
        await widget.store.persistVisitBiometrics(
          chartId: chart.id,
          biometrics: biometrics,
        );
      }
      widget.store.activeVisitSessionId = session.id;
      if (mounted) setState(() {});
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

  /// PO v4.5 — [상담 시작] → timer T0 + chart writer.
  Future<void> _beginConsultation(VisitSession session) async {
    final timer = VisitTimerStore.instance;
    if (timer.active == null ||
        timer.active!.visitSessionId != session.id ||
        timer.active!.consultationStartedAt == null) {
      await timer.startConsultation(
        visitSessionId: session.id,
        shopId: session.shopId,
      );
    }
    widget.store.activeVisitSessionId = session.id;
    await _openChartForSession(session);
  }

  Future<void> _openChartForSession(VisitSession session) async {
    final customer = widget.store.findCustomer(session.customerId);
    if (customer == null || !mounted) return;
    final chart = widget.store.chartForVisitSession(session);
    await VisitTimerStore.instance.onChartOpened(session.id);
    if (!mounted) return;
    await openChartWriterForCustomer(
      context,
      store: widget.store,
      customer: customer,
      existingChart: chart,
    );
    await VisitTimerStore.instance.onChartClosed(session.id);
    if (mounted) setState(() {});
  }

  Future<void> _handleCareStart(VisitSession session) async {
    await VisitTimerStore.instance.startCare();
    if (mounted) setState(() {});
  }

  Future<void> _handleCareEnd(VisitSession session) async {
    await VisitTimerStore.instance.endCare();
    if (mounted) setState(() {});
  }

  Future<void> _captureAfterPhoto(VisitSession session) async {
    final customer = widget.store.findCustomer(session.customerId);
    final chart = widget.store.chartForVisitSession(session);
    if (customer == null || chart == null || !mounted) return;

    final result = await SmartGuideCameraPage.open(
      context,
      shopId: widget.store.shop.id,
      customerId: customer.id,
      kind: GuideCameraKind.after,
      ghostBeforeUrl: chart.beforeImageUrl,
    );
    if (result == null || !mounted) return;

    await widget.store.patchChartAfterImage(
      chartId: chart.id,
      afterImageUrl: result.url,
    );
    await VisitTimerStore.instance.markAfterPhotoCaptured();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('After 저장 완료'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {});
    }
  }

  Future<void> _endVisit(VisitSession session) async {
    final timer = VisitTimerStore.instance;
    final report = await timer.buildReportBlock();
    final chart = widget.store.chartForVisitSession(session);
    if (chart != null && report.isNotEmpty) {
      final summary = chart.treatmentSummary.trim();
      final next = summary.isEmpty ? report : '$summary\n\n$report';
      await widget.store.updateCustomerChartFields(
        chartId: chart.id,
        treatmentSummary: next,
      );
    }
    await timer.endVisit();
    await visit.completeVisit(session.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          chart?.afterImageUrl?.trim().isEmpty ?? true
              ? '방문 종료 · 애프터 미촬영'
              : '방문 종료 · 관리 리포트 저장',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _load(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final snap = _agendaSnapshot();
    final meta = '예약 ${snap.scheduledCount} · 진행 ${snap.inProgressCount}';

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
                  meta,
                  style: TextStyle(
                    fontSize: 15,
                    color: SoriTokens.textSecondary.withValues(alpha: 0.95),
                    height: 1.35,
                  ),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (_climate != null && _trends != null)
                SliverToBoxAdapter(
                  child: ConsultationWidgetBoard(
                    climate: _climate!,
                    trends: _trends!,
                    tempoLevel: computeTempoLevel(
                      scheduledCount: snap.scheduledCount,
                      inProgressCount: snap.inProgressCount,
                    ),
                    onEnvironmentDetail: () => _openClinicalSheet(),
                    onTrendDetail: () => _openClinicalSheet(
                      trend: _trends!.briefingLead,
                    ),
                  ),
                ),
              if (snap.activeSessions.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: _SectionHeader(title: '지금 진행 중'),
                ),
                ...snap.activeSessions.map(
                  (session) => SliverToBoxAdapter(
                    child: CareTimerWidget(
                      store: widget.store,
                      session: session,
                      onConsultationStart: () => _beginConsultation(session),
                      onOpenChart: () => _openChartForSession(session),
                      onCareStart: () => _handleCareStart(session),
                      onCareEnd: () => _handleCareEnd(session),
                      onAfterPhoto: () => _captureAfterPhoto(session),
                      onVisitEnd: () => _endVisit(session),
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(
                child: _SectionHeader(title: '오늘의 일정'),
              ),
              if (snap.items.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Text(
                      '오늘 예약된 일정이 없습니다',
                      style: VisitGlassTokens.captionCalm.copyWith(fontSize: 14),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: snap.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = snap.items[i];
                      return _AgendaRow(
                        item: item,
                        session: item.session,
                        store: widget.store,
                        emphasized: item.isNext,
                        onTap: () => _openBriefing(item),
                      );
                    },
                  ),
                ),
              const SliverToBoxAdapter(
                child: _SectionHeader(title: '워크인'),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _WalkInSection(
                    onNewCustomer: _startNewCustomerFlow,
                    onReturningCustomer: _startReturningCustomerFlow,
                    onQuickChart: _openQuickChart,
                  ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: SoriTokens.textPrimary,
        ),
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({
    required this.item,
    required this.store,
    required this.onTap,
    this.session,
    this.emphasized = false,
  });

  final TodayAgendaItem item;
  final VisitSession? session;
  final SoriStore store;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final chart = session != null ? store.chartForVisitSession(session!) : null;
    final visitNo = chart?.visitNumber;
    final phaseLabel = session?.phase.label;
    final scheduleLabel = item.schedule?.careLabel.trim() ?? '';

    return SosSignalBar(
      signal: item.sosSignal,
      child: Material(
        color: VolumeGlassTheme.cardFillColor(),
        elevation: 0,
        shadowColor: Colors.transparent,
        borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius),
              boxShadow: VolumeGlassTheme.volumeShadow(
                tint: emphasized ? VisitGlassTokens.care : Colors.black,
                alpha: emphasized ? 0.06 : 0.05,
              ),
            ),
            child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    item.timeLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: emphasized
                          ? VisitGlassTokens.care
                          : SoriTokens.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: SoriTokens.surface,
                  child: Text(
                    item.customerName.characters.first,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.customerName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.isNext) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: VisitGlassTokens.care
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '다음',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: VisitGlassTokens.care,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                          SosSignalBadge(signal: item.sosSignal),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          item.isReturning ? '재방문' : '신규',
                          if (visitNo != null) '${visitNo}회차',
                          if (scheduleLabel.isNotEmpty) scheduleLabel,
                          if (phaseLabel != null) phaseLabel,
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: SoriTokens.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: SoriTokens.textSecondary,
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WalkInSection extends StatelessWidget {
  const _WalkInSection({
    required this.onNewCustomer,
    required this.onReturningCustomer,
    required this.onQuickChart,
  });

  final VoidCallback onNewCustomer;
  final VoidCallback onReturningCustomer;
  final VoidCallback onQuickChart;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _WalkInCard(
                title: '신규 고객',
                subtitle: 'Before · 동의서',
                icon: Icons.person_add_alt_1_rounded,
                onTap: onNewCustomer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _WalkInCard(
                title: '기존 고객',
                subtitle: 'B/A 회상 · 재방문',
                icon: Icons.history_rounded,
                emphasized: true,
                onTap: onReturningCustomer,
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onQuickChart,
            icon: const Icon(Icons.bolt_rounded, size: 16),
            label: const Text('간편 기록만'),
          ),
        ),
      ],
    );
  }
}

class _WalkInCard extends StatelessWidget {
  const _WalkInCard({
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
      color: emphasized
          ? VisitGlassTokens.care
          : VolumeGlassTheme.cardFillColor(),
      elevation: 0,
      shadowColor: Colors.transparent,
      borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius),
            boxShadow: emphasized
                ? VolumeGlassTheme.volumeShadow(
                    tint: VisitGlassTokens.care,
                    alpha: 0.08,
                  )
                : VolumeGlassTheme.volumeShadow(),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: emphasized ? Colors.white : VisitGlassTokens.care,
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: emphasized ? Colors.white : SoriTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: emphasized
                        ? Colors.white.withValues(alpha: 0.85)
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
