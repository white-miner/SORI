import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/ba_capture_session.dart';
import '../../models/customer.dart';
import '../../models/customer_chart.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../utils/supabase_schema_error.dart';
import '../../views/admin_chart_writer_page.dart';
import '../../views/before_after_compare_page.dart';
import '../../visit_kernel/models/care_schedule_entry.dart';
import '../../visit_kernel/models/visit_session.dart';
import '../../visit_kernel/visit_store.dart';
import '../operation/models/clinical_environment_brief.dart';
import '../operation/models/consultation_deep_mode.dart';
import '../operation/models/clinical_trend_snapshot.dart';
import '../operation/models/shop_climate_context.dart';
import '../operation/models/visit_biometrics.dart';
import '../operation/shop_climate_service.dart';
import '../operation/shop_clinical_trend_service.dart';
import '../operation/visit_timer_store.dart';
import '../operation/widgets/clinical_assistant_sheet.dart';
import '../operation/widgets/consultation_widget_board.dart';
import '../../views/smart_guide_camera_page.dart';
import 'ba_recall_cache.dart';
import 'consultation_track.dart';
import 'home_dashboard_controller.dart';
import 'home_visual_tokens.dart';
import 'management_case_paginator.dart';
import 'today_agenda.dart';
import 'models/care_timer_entry_mode.dart';
import 'visit_existing_customer_picker_page.dart';
import 'visit_new_customer_form_page.dart';
import 'visit_session_view_page.dart';
import '../operation/widgets/care_timer_fullscreen_page.dart';
import 'widgets/active_session_strip.dart';
import 'report/visit_end_pipeline.dart';
import 'widgets/visit_report_send_sheet.dart';
import 'widgets/ba_capture_carousel.dart';
import 'widgets/home_hero_card.dart';
import 'widgets/home_preset_quick_pick.dart';
import 'widgets/home_quick_action_row.dart';
import 'widgets/home_scheduler_strip.dart';
import 'widgets/home_toolbox_row.dart';
import 'widgets/management_case_card.dart';
import 'widgets/quick_calculator_sheet.dart';

/// PRD v7.0 — 원장 홈 상단 탭.
enum HomeTab { myFeed, myAsset, timer }

/// PRD v7.0 — 원장 GNB 홈: My Feed / My Asset / Timer 3탭 셸.
class VisitLauncherPage extends StatefulWidget {
  const VisitLauncherPage({super.key, required this.store});

  final SoriStore store;

  @override
  State<VisitLauncherPage> createState() => _VisitLauncherPageState();
}

class _VisitLauncherPageState extends State<VisitLauncherPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _loading = true;
  ShopClimateContext? _climate;
  ClinicalTrendSnapshot? _trends;
  final HomeDashboardController _homeCtrl = HomeDashboardController();

  late final TabController _tabs;
  final ScrollController _feedScroll = ScrollController();
  final ManagementCasePaginator _casePager = ManagementCasePaginator();

  /// Q3(a) — 🟢 확정 애니메이션이 진행 중인 세션. 320ms 후 목록에서 사라진다.
  String? _baTransferringId;
  bool _baBusy = false;

  /// 상담 중 즐겨찾기한 레퍼런스만 빠르게 훑기 위한 필터.
  bool _caseBookmarkOnly = false;

  VisitStore get visit => widget.store.visit;

  static const _groupedBg = SoriTokens.background;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabs = TabController(length: HomeTab.values.length, vsync: this)
      ..addListener(_onVisit);
    _feedScroll.addListener(_onFeedScroll);
    visit.addListener(_onVisit);
    widget.store.addListener(_onVisit);
    VisitTimerStore.instance.addListener(_onVisit);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    visit.removeListener(_onVisit);
    widget.store.removeListener(_onVisit);
    VisitTimerStore.instance.removeListener(_onVisit);
    _feedScroll.dispose();
    _tabs.dispose();
    _homeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _loading = true);
    await Future.wait([
      visit.ensureLoaded(force: force),
      widget.store.refreshCareScheduleEntries(force: force),
      widget.store.hydrateVisitTimer(),
      widget.store.refreshBaSessions(),
      _loadClimate(),
      _loadTrends(),
    ]);
    if (!mounted) return;
    _autoWarmNextCustomer();
    _reloadCaseFeed();
    setState(() => _loading = false);
  }

  /// 무한 스크롤 소스 — 북마크 필터가 켜지면 즐겨찾기한 케이스로 좁힌다.
  List<CustomerChart> _caseSource() {
    final all = widget.store.managementCaseCharts();
    if (!_caseBookmarkOnly) return all;
    return all
        .where((c) => widget.store.isChartBookmarked(c.id))
        .toList(growable: false);
  }

  void _reloadCaseFeed() {
    _casePager.reset();
    _casePager.loadMore(_caseSource());
  }

  void _toggleCaseBookmarkFilter() {
    setState(() {
      _caseBookmarkOnly = !_caseBookmarkOnly;
      _reloadCaseFeed();
    });
  }

  void _onFeedScroll() {
    if (!_feedScroll.hasClients || !_casePager.hasMore) return;
    final position = _feedScroll.position;
    // 잔여 3건 지점에서 미리 당겨온다 (카드 1장 ≈ 화면 절반).
    if (position.pixels < position.maxScrollExtent - 900) return;
    if (_casePager.loadMore(_caseSource()) > 0) {
      setState(() {});
    }
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(VisitTimerStore.instance.syncOnResume());
    }
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
    final session = widget.store.activeVisitSession;
    if (session != null) await _beginConsultation(session);
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
    final session = widget.store.activeVisitSession;
    if (session != null) await _beginConsultation(session);
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

  void _openSessionView(VisitSession session) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisitSessionViewPage(
          store: widget.store,
          session: session,
          onConsultationStart: () => _beginConsultation(session),
          onOpenChart: () => _openChartForSession(session),
          onPresetSelected: (slot) async {
            await _handlePresetSelected(session, slot);
          },
          onCareEnd: () => _handleCareEnd(session),
          onAfterPhoto: () => _captureAfterPhoto(session),
          onVisitEnd: () => _endVisit(session),
        ),
      ),
    );
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

  Future<void> _openTimerStandalone() async {
    final timerStore = VisitTimerStore.instance;
    await timerStore.ensureStandaloneTimer();
    if (!mounted) return;
    await CareTimerFullscreenPage.open(
      context,
      store: widget.store,
      presetSlot: timerStore.selectedPresetSlot,
      entryMode: CareTimerEntryMode.standalone,
      onPopHome: () {
        if (mounted) setState(() {});
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _openCareStart() async {
    final timerStore = VisitTimerStore.instance;
    await timerStore.ensureStandaloneTimer();
    final quick = timerStore.isPathCEligible;
    final mode = quick
        ? CareTimerEntryMode.careStartQuick
        : CareTimerEntryMode.careStartManual;
    if (quick) {
      final slot = timerStore.homeSelectedPresetSlot!;
      await timerStore.bindPreset(presetSlot: slot);
    }
    if (!mounted) return;
    await CareTimerFullscreenPage.open(
      context,
      store: widget.store,
      presetSlot: timerStore.selectedPresetSlot,
      entryMode: mode,
      onPopHome: () {
        if (mounted) setState(() {});
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _handlePresetSelected(VisitSession session, int slot) async {
    final timerStore = VisitTimerStore.instance;
    timerStore.selectPresetSlot(slot);
    if (timerStore.active == null ||
        timerStore.active!.visitSessionId != session.id) {
      await timerStore.startConsultation(
        visitSessionId: session.id,
        shopId: session.shopId,
      );
    }
    await timerStore.bindPreset(presetSlot: slot);
    if (!mounted) return;
    setState(() {});
    await CareTimerFullscreenPage.open(
      context,
      store: widget.store,
      session: session,
      presetSlot: slot,
      onCareEnd: () => _handleCareEnd(session),
      onVisitEnd: () async {
        await _endVisit(session);
        if (mounted) Navigator.of(context).pop();
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _openCareTimerFullscreen(VisitSession session) async {
    final slot = VisitTimerStore.instance.selectedPresetSlot;
    await CareTimerFullscreenPage.open(
      context,
      store: widget.store,
      session: session,
      presetSlot: slot,
      entryMode: CareTimerEntryMode.standalone,
      onCareEnd: () => _handleCareEnd(session),
      onVisitEnd: () async {
        await _endVisit(session);
        if (mounted) Navigator.of(context).pop();
      },
    );
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
    final pipeline = VisitEndPipeline(
      store: widget.store,
      visitStore: visit,
      timerStore: VisitTimerStore.instance,
    );
    final result = await pipeline.run(session: session);
    if (!mounted) return;

    final chart = widget.store.chartForVisitSession(session);
    final customer =
        chart != null ? widget.store.findCustomer(chart.customerId) : null;

    if (result.hasReport) {
      await VisitReportSendSheet.show(
        context,
        report: result.report!,
        customerPhone: customer?.phone ?? '',
        store: widget.store,
      );
    } else {
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
    }
    await _load(force: true);
  }

  // ── PRD v7.0 ③ B/A 캐러셀 ──────────────────────────────────────────

  Future<void> _captureBaPhoto(BaCaptureSession? session, String kind) async {
    if (_baBusy) return;
    setState(() => _baBusy = true);
    try {
      final target = session ?? await widget.store.createBaSession();
      if (!mounted) return;

      final isBefore = kind != 'after';
      final result = await SmartGuideCameraPage.open(
        context,
        shopId: target.shopId,
        // public 버킷이므로 UUID 토큰 경로로 URL 추측을 어렵게 한다.
        customerId: SoriStore.baDraftStorageSegment(target.sessionToken),
        kind: isBefore ? GuideCameraKind.before : GuideCameraKind.after,
        ghostBeforeUrl: isBefore ? null : target.ghostBeforeUrl,
      );
      if (result == null || !mounted) return;

      await widget.store.attachBaPhoto(
        target: target,
        kind: isBefore ? 'before' : 'after',
        imageUrl: result.url,
      );
    } catch (e) {
      if (!mounted) return;
      _toast('촬영 저장 실패: ${_readableError(e)}', error: true);
    } finally {
      if (mounted) setState(() => _baBusy = false);
    }
  }

  /// 원장님 화면에 PostgrestException 원문이 그대로 뜨면 대응할 방법이 없다.
  String _readableError(Object e) => isMissingSchemaError(e)
      ? '서버 준비가 끝나지 않았습니다. 잠시 후 다시 시도해 주세요'
      : '$e';

  Future<void> _deferBaSession(BaCaptureSession session) async {
    try {
      await widget.store.deferBaSession(session);
    } catch (e) {
      if (mounted) _toast('처리 실패: ${_readableError(e)}', error: true);
    }
  }

  /// 🟢 이관 — 고객을 고르고, 320ms 확정 애니메이션 후 🟢 카드로 굳는다.
  ///
  /// v7.0.2 — 카드는 캐러셀에 남는다. 피드에는 같은 케이스가 추가로 꽂힌다.
  Future<void> _bindBaSession(BaCaptureSession session) async {
    if (_baBusy) return;
    final customer = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(
        builder: (_) => VisitExistingCustomerPickerPage(store: widget.store),
      ),
    );
    if (customer == null || !mounted) return;

    setState(() {
      _baBusy = true;
      _baTransferringId = session.id;
    });
    try {
      final chart = await widget.store.bindBaSessionToChart(
        target: session,
        customerId: customer.id,
      );
      // 확정 애니메이션이 끝나는 시점에 맞춰 피드 최상단에 꽂는다.
      await Future<void>.delayed(HomeVisualTokens.baTransferDuration);
      if (!mounted) return;
      _casePager.prepend(chart);
      _toast('${customer.name} · ${chart.visitNumber}회 케이스로 이관');
    } catch (e) {
      if (!mounted) return;
      _toast('고객 연결 실패: ${_readableError(e)}', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _baBusy = false;
          _baTransferringId = null;
        });
      }
    }
  }

  // ── PRD v7.0 ④ 관리 케이스 ─────────────────────────────────────────

  Future<void> _toggleCaseBookmark(CustomerChart chart) async {
    try {
      await widget.store.toggleCaseBookmark(chart.id);
      // 필터가 켜진 상태에서 해제하면 그 카드는 목록에서 빠져야 한다.
      if (mounted && _caseBookmarkOnly) setState(_reloadCaseFeed);
    } catch (e) {
      if (mounted) _toast('보관함 처리 실패: $e', error: true);
    }
  }

  /// 🟢 카드 탭 — 이관된 케이스를 뷰어로 연다.
  ///
  /// 차트를 못 찾으면(로컬 폴백 등) 뷰어 대신 피드의 해당 카드로 스크롤한다.
  Future<void> _openBaSession(BaCaptureSession session) async {
    final chartId = session.chartId?.trim() ?? '';
    if (chartId.isEmpty) return;

    final chart = widget.store.findChartById(chartId);
    if (chart != null) {
      await _openCaseCompare(chart);
      return;
    }
    _focusCaseInFeed(chartId);
  }

  /// 피드에 이미 로드된 케이스라면 그 위치로 스크롤해 준다.
  void _focusCaseInFeed(String chartId) {
    final index = _casePager.items.indexWhere((c) => c.id == chartId);
    if (index < 0 || !_feedScroll.hasClients) return;
    final target = (_feedScroll.position.maxScrollExtent *
            (index / _casePager.items.length))
        .clamp(0.0, _feedScroll.position.maxScrollExtent);
    _feedScroll.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openCaseCompare(CustomerChart chart) async {
    final customer = widget.store.findCustomer(chart.customerId);
    await openBeforeAfterComparePage(
      context: context,
      customerName: customer?.name ?? '고객',
      charts: widget.store.chartsForCustomer(chart.customerId),
      initialChartId: chart.id,
      initialCareName: chart.careName,
    );
  }

  void _openSchedulerSheet() {
    final entries = HomeSchedulerStrip.todayEntries(widget.store);
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _SchedulerSheet(entries: entries),
      ),
    );
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? SoriTokens.systemRed : SoriTokens.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final careRunning = VisitTimerStore.instance.isCareRunning;

    return ColoredBox(
      color: _groupedBg,
      child: Stack(
        children: [
          Column(
            children: [
              _HomeTabBar(controller: _tabs, careRunning: careRunning),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabs,
                        children: [
                          _buildMyFeed(careRunning),
                          const _ComingSoonPane(
                            title: 'My Asset',
                            subtitle: '샵 자산 대시보드는 다음 스프린트에서 열립니다',
                            icon: Icons.donut_large_rounded,
                          ),
                          _buildTimerPane(careRunning),
                        ],
                      ),
              ),
            ],
          ),
          if (_homeCtrl.calculatorOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSlide(
                offset: _homeCtrl.calculatorOpen
                    ? Offset.zero
                    : const Offset(0, 1),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: const QuickCalculatorSheet(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMyFeed(bool careRunning) {
    final drafts = widget.store.baCarouselSessions;
    final cases = _casePager.items;

    return RefreshIndicator(
      color: SoriTokens.primary,
      onRefresh: () => _load(force: true),
      child: CustomScrollView(
        controller: _feedScroll,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: ListenableBuilder(
              listenable: _homeCtrl,
              builder: (context, _) => HomeHeroCard(
                store: widget.store,
                controller: _homeCtrl,
                careRunning: careRunning,
                schedulerStrip: HomeSchedulerStrip(
                  store: widget.store,
                  onTap: _openSchedulerSheet,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: HomeQuickActionRow(
                onNewCustomer: _startNewCustomerFlow,
                onReturningCustomer: _startReturningCustomerFlow,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: BaCaptureCarousel(
              sessions: drafts,
              transferringId: _baTransferringId,
              offlineDraft: !widget.store.baRemoteReady,
              onCapture: _captureBaPhoto,
              onBind: _bindBaSession,
              onDefer: _deferBaSession,
              onOpen: (s) => unawaited(_openBaSession(s)),
            ),
          ),
          SliverToBoxAdapter(
            child: _CaseFeedHeader(
              bookmarkOnly: _caseBookmarkOnly,
              onToggleBookmark: _toggleCaseBookmarkFilter,
            ),
          ),
          if (cases.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyCaseFeed(bookmarkOnly: _caseBookmarkOnly),
            )
          else
            SliverList.builder(
              itemCount: cases.length,
              itemBuilder: (context, index) {
                final chart = cases[index];
                return ManagementCaseCard(
                  key: ValueKey(chart.id),
                  chart: chart,
                  bookmarked: widget.store.isChartBookmarked(chart.id),
                  onBookmark: () => unawaited(_toggleCaseBookmark(chart)),
                  onExpand: () => unawaited(_openCaseCompare(chart)),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }

  /// Q1(b) — v5.4 자산 3종을 시각 스펙 변경 없이 이 탭으로 모았다.
  Widget _buildTimerPane(bool careRunning) {
    final snap = _agendaSnapshot();
    final heroSession = snap.activeSessions.firstOrNull ??
        widget.store.activeVisitSession;

    return RefreshIndicator(
      color: SoriTokens.primary,
      onRefresh: () => _load(force: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: ListenableBuilder(
              listenable: _homeCtrl,
              builder: (context, _) => HomeToolboxRow(
                controller: _homeCtrl,
                careRunning: careRunning,
                climate: _climate,
                onTimerTap: () {
                  _homeCtrl.selectTimerTool();
                  unawaited(_openTimerStandalone());
                },
                onWeatherTap: () => _openClinicalSheet(),
              ),
            ),
          ),
          if (careRunning)
            SliverToBoxAdapter(
              child: ActiveSessionStrip(
                store: widget.store,
                session: heroSession,
                onTap: heroSession != null
                    ? () => _openCareTimerFullscreen(heroSession)
                    : _openTimerStandalone,
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: _CareStartButton(onTap: _openCareStart),
            ),
          ),
          SliverToBoxAdapter(
            child: HomePresetQuickPick(
              timerStore: VisitTimerStore.instance,
              onSlotSelected: (slot) {
                unawaited(
                  VisitTimerStore.instance.toggleHomePresetSlot(slot),
                );
              },
              onConfigureSlot: (slot) {
                unawaited(_openTimerStandalone());
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }
}

class _HomeTabBar extends StatelessWidget {
  const _HomeTabBar({required this.controller, required this.careRunning});

  final TabController controller;
  final bool careRunning;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: HomeVisualTokens.tabBarHeight,
      child: TabBar(
        controller: controller,
        labelColor: HomeVisualTokens.tabActiveColor,
        unselectedLabelColor: HomeVisualTokens.tabInactiveColor,
        // 전역 soriTabBarTheme은 채워진 검정 칩 indicator를 쓴다. 그대로 두면
        // 검정 칩 위에 검정 라벨이 얹혀 선택된 탭이 통째로 까맣게 보인다.
        // 밑줄 indicator로 덮어써 라벨이 선명한 블랙으로 읽히게 한다.
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(
            color: HomeVisualTokens.tabActiveColor,
            width: 2,
          ),
          insets: EdgeInsets.symmetric(horizontal: 20),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontSize: HomeVisualTokens.tabLabelSize,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: HomeVisualTokens.tabLabelSize,
          fontWeight: FontWeight.w600,
        ),
        tabs: [
          const Tab(text: 'My Feed'),
          const Tab(text: 'My Asset'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Timer'),
                // 케어 진행 중임을 탭 밖에서도 알 수 있게 한다.
                if (careRunning) ...[
                  const SizedBox(width: 5),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: HomeVisualTokens.careGreen,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonPane extends StatelessWidget {
  const _ComingSoonPane({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: HomeVisualTokens.dateIconColor),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: HomeVisualTokens.dateTextColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: HomeVisualTokens.dateIconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaseFeedHeader extends StatelessWidget {
  const _CaseFeedHeader({
    required this.bookmarkOnly,
    required this.onToggleBookmark,
  });

  final bool bookmarkOnly;
  final VoidCallback onToggleBookmark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 8, 10),
      child: Row(
        children: [
          const Text(
            '관리 케이스',
            style: TextStyle(
              fontSize: HomeVisualTokens.sectionLabelSize,
              fontWeight: FontWeight.w700,
              color: HomeVisualTokens.sectionLabelColor,
            ),
          ),
          if (bookmarkOnly) ...[
            const SizedBox(width: 8),
            const Text(
              '즐겨찾기만',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: SoriTokens.primary,
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            onPressed: onToggleBookmark,
            visualDensity: VisualDensity.compact,
            tooltip: bookmarkOnly ? '전체 케이스 보기' : '즐겨찾기한 케이스만 보기',
            icon: Icon(
              bookmarkOnly
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              size: 20,
              color: bookmarkOnly
                  ? SoriTokens.primary
                  : HomeVisualTokens.dateIconColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCaseFeed extends StatelessWidget {
  const _EmptyCaseFeed({required this.bookmarkOnly});

  final bool bookmarkOnly;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
      child: Column(
        children: [
          Icon(
            bookmarkOnly
                ? Icons.bookmark_border_rounded
                : Icons.photo_library_outlined,
            size: 30,
            color: HomeVisualTokens.dateIconColor,
          ),
          const SizedBox(height: 10),
          Text(
            bookmarkOnly
                ? '즐겨찾기한 케이스가 없습니다'
                : '완성된 B/A 케이스가 아직 없습니다',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: HomeVisualTokens.dateTextColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            bookmarkOnly
                ? '카드 우측 상단 책갈피를 눌러 상담용 레퍼런스를 모아 두세요'
                : '위 B/A 등록에서 Before·After를 찍고 고객에 연결해 보세요',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: HomeVisualTokens.dateIconColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SchedulerSheet extends StatelessWidget {
  const _SchedulerSheet({required this.entries});

  final List<CareScheduleEntry> entries;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '오늘 일정',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  '등록된 일정이 없습니다',
                  style: TextStyle(
                    fontSize: 13,
                    color: HomeVisualTokens.dateIconColor,
                  ),
                ),
              )
            else
              ...entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: HomeVisualTokens.memoDotSize,
                        height: HomeVisualTokens.memoDotSize,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: HomeVisualTokens.memoActiveFill,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          HomeSchedulerStrip.labelFor(e),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (e.note.trim().isNotEmpty)
                        Flexible(
                          child: Text(
                            e.note.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: HomeVisualTokens.dateIconColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CareStartButton extends StatelessWidget {
  const _CareStartButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x1F34C759),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF34C759),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: const Text(
            '케어 시작',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
