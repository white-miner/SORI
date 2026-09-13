import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../content_atomizer/content_atomizer.dart';
import '../../features/publish_rail/publish_rail_sheet.dart';
import '../../models/chart_interview_chips.dart';
import '../../models/customer.dart';
import '../../models/customer_chart.dart';
import '../../models/home_care_prescriptions.dart';
import '../../services/chart_signature_storage.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../utils/sori_shell_insets.dart';
import '../../views/chart_consent_tab.dart';
import '../../views/chart_management_page.dart';
import '../../views/customer_chart/customer_chart_page.dart';
import '../../views/smart_guide_camera_page.dart';
import '../../visit_kernel/models/care_schedule_entry.dart';
import '../../visit_kernel/models/visit_session.dart';
import '../../visit_kernel/theme/visit_glass_tokens.dart';
import '../../visit_kernel/visit_store.dart';
import '../../visit_kernel/widgets/visit_glass_widgets.dart';
import '../operation/models/consultation_deep_mode.dart';
import '../operation/models/clinical_environment_brief.dart';
import '../operation/models/visit_biometrics.dart';
import '../operation/widgets/sori_narrative_block.dart';
import 'ba_recall_cache.dart';
import 'ba_recall_overlay.dart';
import 'consultation_surface_page.dart';
import 'consultation_track.dart';

enum _VisitCompleteChoice { customerDetail, nextSchedule, close }

const double _kVisitPhaseGutter = 20;
const double _kVisitConsentActionPad = 16;

EdgeInsets _visitPhaseListPadding(BuildContext context) {
  return EdgeInsets.fromLTRB(
    _kVisitPhaseGutter,
    _kVisitPhaseGutter,
    _kVisitPhaseGutter,
    _kVisitPhaseGutter + SoriShellInsets.scrollBottomInset(context),
  );
}

EdgeInsets _visitFixedActionPadding(
  BuildContext context, {
  required double existing,
}) {
  return EdgeInsets.fromLTRB(
    existing,
    existing,
    existing,
    existing + SoriShellInsets.scrollBottomInset(context),
  );
}

/// Visit Session — Shoot → Consult → Plan → Consent → Publish (PRD v3.1).
class VisitSessionPage extends StatefulWidget {
  const VisitSessionPage({
    super.key,
    required this.store,
    required this.sessionId,
    required this.track,
    this.deepMode = ConsultationDeepMode.fullDesign,
    this.biometrics,
    this.environmentBrief = ClinicalEnvironmentBrief.standard,
  });

  final SoriStore store;
  final String sessionId;
  final ConsultationTrack track;
  final ConsultationDeepMode deepMode;
  final VisitBiometrics? biometrics;
  final ClinicalEnvironmentBrief environmentBrief;

  /// 대기열·외부 진입 시 차트 이력으로 트랙 자동 판별.
  static ConsultationTrack resolveTrack(
    SoriStore store,
    VisitSession session,
  ) {
    final chart = store.chartForVisitSession(session);
    final hasPrior = store
        .chartsForCustomer(session.customerId)
        .any((c) => c.id != chart?.id);
    return hasPrior
        ? ConsultationTrack.returning
        : ConsultationTrack.newCustomer;
  }

  @override
  State<VisitSessionPage> createState() => _VisitSessionPageState();
}

class _VisitSessionPageState extends State<VisitSessionPage> {
  late final SignatureController _signatureController;
  late final TextEditingController _summaryCtrl;
  late final TextEditingController _insightCtrl;
  bool _busy = false;
  bool _baWarm = false;

  bool _consentCare = false;
  bool _consentAbnormal = false;
  bool _consentRefund = false;
  bool _consentPhoto = false;
  bool _consentMarketing = false;
  bool _consentOffline = false;

  final Set<String> _concerns = {};

  VisitStore get visit => widget.store.visit;

  VisitSession? get _session => widget.store.findVisitSession(widget.sessionId);

  Customer? get _customer {
    final sid = _session?.customerId;
    if (sid == null) return null;
    return widget.store.findCustomer(sid);
  }

  CustomerChart? get _chart {
    final s = _session;
    if (s == null) return null;
    return widget.store.chartForVisitSession(s);
  }

  /// Explicit Two-Track from launcher overrides chart heuristics.
  bool get _isReturningFlow => widget.track == ConsultationTrack.returning;

  bool get _isNewFlow => widget.track == ConsultationTrack.newCustomer;

  CustomerChart? get _lastPriorChart {
    final customer = _customer;
    final currentId = _chart?.id;
    if (customer == null) return null;
    final prior = widget.store
        .chartsForCustomer(customer.id)
        .where((c) => c.id != currentId)
        .toList()
      ..sort((a, b) {
        final ad = a.visitCheckedAt ?? a.createdAt ?? DateTime(1970);
        final bd = b.visitCheckedAt ?? b.createdAt ?? DateTime(1970);
        return bd.compareTo(ad);
      });
    return prior.isEmpty ? null : prior.first;
  }

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 2.5,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    _summaryCtrl = TextEditingController(
      text: _chart?.treatmentSummary.trim() ?? '',
    );
    _insightCtrl = TextEditingController(
      text: _chart?.directorInsight.trim() ?? '',
    );
    widget.store.addListener(_onStore);
    _hydrateFromChart();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isReturningFlow) unawaited(_prefetchBaRecall());
    });
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    _signatureController.dispose();
    _summaryCtrl.dispose();
    _insightCtrl.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Future<void> _prefetchBaRecall() async {
    final customer = _customer;
    if (customer == null || !mounted) return;
    await BaRecallCache.instance.prefetch(
      widget.store,
      customer.id,
      imageContext: context,
    );
    if (mounted) {
      setState(() => _baWarm = BaRecallCache.instance.isWarm(customer.id));
    }
  }

  Future<void> _openBaRecall() async {
    final customer = _customer;
    if (customer == null) return;

    final sw = Stopwatch()..start();
    final cache = BaRecallCache.instance;
    if (!cache.isWarm(customer.id)) {
      await cache.prefetch(
        widget.store,
        customer.id,
        imageContext: mounted ? context : null,
      );
    }
    final thumbs = cache.thumbsFor(customer.id);
    final warm = cache.isWarm(customer.id);
    sw.stop();

    if (!mounted) return;
    debugPrint(
      'BaRecall open: warm=$warm elapsed=${sw.elapsedMilliseconds}ms '
      'thumbs=${thumbs.length}',
    );

    await showBaRecallOverlay(
      context: context,
      thumbs: thumbs.isEmpty
          ? BaRecallCache.buildFromStore(widget.store, customer.id)
          : thumbs,
      wasWarm: warm,
    );
  }

  Future<void> _savePlanAndAdvance({
    required String treatmentSummary,
    required List<String> homeCarePrescriptions,
    DateTime? nextVisitAt,
  }) async {
    final chart = _chart;
    final customer = _customer;
    if (chart == null || customer == null || _busy) return;

    setState(() => _busy = true);
    try {
      await widget.store.updateCustomerChartFields(
        chartId: chart.id,
        treatmentSummary: treatmentSummary,
        directorInsight: _insightCtrl.text.trim(),
        homeCarePrescriptions: homeCarePrescriptions,
      );

      if (nextVisitAt != null) {
        await widget.store.addManualCareSchedule(
          scheduledAt: nextVisitAt,
          customerName: customer.name,
          customerId: customer.id,
          customerPhone: customer.phone,
          careLabel: chart.careName.trim().isEmpty
              ? '다음 관리'
              : chart.careName.trim(),
          note: treatmentSummary.trim(),
        );
      }

      await _setPhase(VisitPhase.consent);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('관리 계획이 저장되었습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('관리 계획 저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _hydrateFromChart() {
    final chart = _chart;
    if (chart == null) return;
    _concerns.addAll(chart.concernChips);
    _consentCare = chart.consentMandatory;
    _consentPhoto = chart.consentPhoto;
    _consentMarketing = chart.consentMarketing;
    _consentOffline = chart.consentOfflineOnly;
    final summary = chart.treatmentSummary.trim();
    if (_summaryCtrl.text.trim() != summary) {
      _summaryCtrl.text = summary;
    }
    final insight = chart.directorInsight.trim();
    if (_insightCtrl.text.trim() != insight) {
      _insightCtrl.text = insight;
    }
  }

  /// 요약만 차트에 반영 — visitChecked/동의/발행을 건드리지 않는다.
  Future<void> _persistSummaryOnly() async {
    final chart = _chart;
    if (chart == null) return;
    final text = _summaryCtrl.text.trim();
    if (text == chart.treatmentSummary.trim()) return;
    try {
      await widget.store.updateCustomerChartFields(
        chartId: chart.id,
        treatmentSummary: text,
      );
    } catch (_) {}
  }

  /// 관찰(directorInsight)만 반영 — 완료/동의 상태를 건드리지 않는다.
  Future<void> _persistInsightOnly() async {
    final chart = _chart;
    if (chart == null) return;
    final text = _insightCtrl.text.trim();
    if (text == chart.directorInsight.trim()) return;
    try {
      await widget.store.updateCustomerChartFields(
        chartId: chart.id,
        directorInsight: text,
      );
    } catch (_) {}
  }

  Future<void> _openThirtySecondDetails() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModal) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '더 자세히 남기기',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '요약은 그대로 두고, 이야기·관찰만 보조로 남깁니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '고객 이야기',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '고객이 원한 점이나 확인한 내용을 남겨 보세요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: SoriTokens.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ChartInterviewChips.skinConcerns.map((c) {
                        final selected = _concerns.contains(c);
                        return FilterChip(
                          label: Text(c),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              if (_concerns.contains(c)) {
                                _concerns.remove(c);
                              } else {
                                _concerns.add(c);
                              }
                            });
                            setModal(() {});
                            unawaited(_persistConcerns());
                          },
                          selectedColor:
                              VisitGlassTokens.care.withValues(alpha: 0.25),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '관찰',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '원장이 확인한 점을 짧게 남겨 보세요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: SoriTokens.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _insightCtrl,
                      maxLines: 3,
                      minLines: 2,
                      onEditingComplete: _persistInsightOnly,
                      decoration: InputDecoration(
                        hintText: '관찰 메모 (선택)',
                        filled: true,
                        fillColor: SoriTokens.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '홈케어·다음 일정은 다음 관리 단계에서 남길 수 있어요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: SoriTokens.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          unawaited(_persistInsightOnly());
                          Navigator.pop(ctx);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: SoriTokens.brand,
                          foregroundColor: SoriTokens.onBrand,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('확인'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _setPhase(VisitPhase phase) async {
    await visit.setPhase(widget.sessionId, phase);
  }

  Future<void> _shoot(GuideCameraKind kind) async {
    final customer = _customer;
    final chart = _chart;
    if (customer == null || chart == null || _busy) return;

    setState(() => _busy = true);
    try {
      final ghost = kind == GuideCameraKind.after
          ? chart.beforeImageUrl
          : null;

      final result = await SmartGuideCameraPage.open(
        context,
        shopId: widget.store.shop.id,
        customerId: customer.id,
        kind: kind,
        ghostBeforeUrl: ghost,
      );
      if (!mounted || result == null) return;

      if (result.kind == GuideCameraKind.before) {
        await widget.store.updateCustomerChartFields(
          chartId: chart.id,
          beforeImageUrl: result.url,
        );
      } else {
        await widget.store.patchChartAfterImage(
          chartId: chart.id,
          afterImageUrl: result.url,
        );
      }

      unawaited(_prefetchBaRecall());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.kind == GuideCameraKind.before
                  ? 'Before 저장 완료'
                  : 'After 저장 완료',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openConsultSurface() {
    final chart = _chart;
    final customer = _customer;
    if (chart == null || customer == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConsultationSurfacePage(
          customerName: customer.name,
          chart: chart,
          careLabel: chart.careName,
          // Default director assist view; BaRecall overlay owns Co-view toggle.
          customerCoView: false,
        ),
      ),
    );
  }

  Future<void> _saveConsentAndAdvance() async {
    final customer = _customer;
    final chart = _chart;
    if (customer == null || chart == null || _busy) return;

    if (!_consentCare || !_consentAbnormal || !_consentRefund) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('필수 동의 항목을 모두 체크해 주세요.')),
      );
      return;
    }

    if (_signatureController.isEmpty &&
        (chart.signatureUrl?.trim().isEmpty ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서명을 입력해 주세요.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      String? signatureUrl = chart.signatureUrl;
      if (_signatureController.isNotEmpty) {
        final bytes = await _signatureController.toPngBytes();
        if (bytes != null) {
          signatureUrl = await ChartSignatureStorage.uploadPngOrDataUrl(
            bytes: bytes,
            shopId: widget.store.shop.id,
            customerId: customer.id,
          );
        }
      }

      final saved = await widget.store.saveChartAndConfirmVisitAsync(
        customerId: customer.id,
        chartId: chart.id,
        visitNumber: chart.visitNumber,
        careName: chart.careName,
        treatmentSummary: _summaryCtrl.text.trim().isEmpty
            ? chart.treatmentSummary
            : _summaryCtrl.text.trim(),
        directorInsight: _insightCtrl.text.trim().isEmpty
            ? chart.directorInsight
            : _insightCtrl.text.trim(),
        concernChips: _concerns.toList(),
        firstVisitFearChips: chart.firstVisitFearChips,
        revisitFeedbackChips: chart.revisitFeedbackChips,
        beforeImageUrl: chart.beforeImageUrl,
        afterImageUrl: chart.afterImageUrl,
        consentMandatory: true,
        consentPhoto: _consentPhoto,
        consentMarketing: _consentMarketing,
        consentOfflineOnly: _consentOffline,
        signatureUrl: signatureUrl,
        signaturePngBytes: _signatureController.isNotEmpty
            ? await _signatureController.toPngBytes()
            : null,
        homeCarePrescriptions: chart.homeCarePrescriptions,
        publishToCommunity: false,
      );

      await _setPhase(VisitPhase.publish);
      if (!mounted) return;

      final session = widget.store.findVisitSession(widget.sessionId);
      if (session != null) {
        final atomized = ContentAtomizer.atomize(
          session: session,
          chart: saved,
          shopName: widget.store.shop.name,
        );

        await showPublishRailSheet(
          context,
          store: widget.store,
          session: session,
          chart: saved,
          initialDrafts: atomized.drafts,
        );
      }

      await _setPhase(VisitPhase.done);
      if (!mounted) return;

      await _presentVisitCompleteNext(saved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  CareScheduleEntry? _upcomingScheduleFor({
    required String customerId,
    required CustomerChart chart,
  }) {
    final anchor = chart.visitCheckedAt ?? chart.createdAt ?? DateTime.now();
    final upcoming = widget.store.careScheduleEntries
        .where(
          (e) =>
              (e.customerId ?? '') == customerId &&
              e.status == CareScheduleStatus.scheduled &&
              !e.scheduledAt.isBefore(anchor),
        )
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  String _fmtSchedule(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} $hh:$mm';
  }

  /// R1-3: Publish/동의 완료 후 다음 행동. 자동 홈 복귀 금지.
  Future<void> _presentVisitCompleteNext(CustomerChart saved) async {
    final customer = _customer;
    if (!mounted || customer == null) return;

    final next = _upcomingScheduleFor(
      customerId: customer.id,
      chart: saved,
    );

    final choice = await showModalBottomSheet<_VisitCompleteChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '기록이 마무리됐어요',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '동의와 기록 마무리가 끝난 방문입니다. 다음으로 무엇을 볼까요?',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: SoriTokens.textSecondary,
                ),
              ),
              if (next != null) ...[
                const SizedBox(height: 10),
                Text(
                  '다음 일정 ${_fmtSchedule(next.scheduledAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: SoriTokens.textTertiary,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(ctx, _VisitCompleteChoice.customerDetail),
                style: FilledButton.styleFrom(
                  backgroundColor: SoriTokens.brand,
                  foregroundColor: SoriTokens.onBrand,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('고객 상세 보기'),
              ),
              if (next != null) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () =>
                      Navigator.pop(ctx, _VisitCompleteChoice.nextSchedule),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SoriTokens.textPrimary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('다음 일정 보기'),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, _VisitCompleteChoice.close),
                child: const Text('닫기'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;

    final nav = Navigator.of(context);
    final store = widget.store;
    final customerId = customer.id;
    final chartId = saved.id;

    // Leave VisitSession (was pushed from ShootHub). Never auto-jump to Home.
    nav.pop();

    if (choice == _VisitCompleteChoice.customerDetail) {
      await nav.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CustomerChartPage(
            store: store,
            customerId: customerId,
          ),
        ),
      );
    } else if (choice == _VisitCompleteChoice.nextSchedule) {
      await nav.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChartManagementPage(
            store: store,
            customerId: customerId,
            initialChartId: chartId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final customer = _customer;
    final chart = _chart;

    if (session == null || customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('상담')),
        body: const Center(child: Text('세션을 찾을 수 없습니다.')),
      );
    }

    final phase = session.phase;
    final biometrics =
        widget.biometrics ?? chart?.visitBiometrics ?? const VisitBiometrics();
    final phaseIndex = phase == VisitPhase.done || phase == VisitPhase.hold
        ? VisitPhase.workflow.length - 1
        : phase.workflowIndex.clamp(0, VisitPhase.workflow.length - 1);
    final showBaPill =
        _isReturningFlow &&
        (phase == VisitPhase.consult || phase == VisitPhase.plan);
    final prior = _lastPriorChart;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text(
          _isReturningFlow
              ? '${customer.name}님 · 재방문 상담'
              : '${customer.name}님 · 첫 상담',
        ),
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        actions: [
          if (showBaPill)
            IconButton(
              tooltip: _baWarm ? '과거 B/A · 즉시' : '과거 B/A 보기',
              onPressed: _openBaRecall,
              icon: Icon(
                Icons.photo_library_outlined,
                color: _baWarm
                    ? SoriTokens.semanticYellow
                    : SoriTokens.textSecondary,
              ),
            ),
        ],
      ),
      // DESIGN LAWS: filled primary는 phase CTA 1개. B/A는 AppBar 보조.
      floatingActionButton: null,
      body: session.isOnHold
          ? _HoldPhasePanel(
              chart: chart,
              onResume: () => _setPhase(VisitPhase.consult),
              onCompleteHomeCare: () => _setPhase(VisitPhase.consent),
            )
          : Column(
        children: [
          _DeepModeBanner(mode: widget.deepMode),
          if (widget.environmentBrief.shouldSurface)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: VisitGlassTokens.cardDecoration(),
                child: SoriNarrativeBlock(
                  headline: widget.environmentBrief.headline,
                  narrative:
                      '${widget.environmentBrief.narrative} · 진정 ${widget.environmentBrief.calmTargetC.toStringAsFixed(1)}°C · 장비 상한 L${widget.environmentBrief.deviceIntensityCap}',
                  icon: Icons.eco_outlined,
                  compact: true,
                ),
              ),
            ),
          for (final hint in biometrics.hints)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: VisitGlassTokens.cardDecoration(),
                child: SoriNarrativeBlock(
                  headline: hint.headline,
                  narrative: hint.narrative,
                  icon: Icons.monitor_heart_outlined,
                  compact: true,
                ),
              ),
            ),
          if (_isReturningFlow && prior != null)
            _ReturningContextBanner(
              prior: prior,
              baWarm: _baWarm,
              onOpenBaRecall: _openBaRecall,
            ),
          if (_isNewFlow)
            const _NewCustomerOnboardingBanner(),
          // R1-1/R1-2: 요약 히어로 · 30초 상세는 시트로 (본문 Column overflow 방지).
          _CareSummaryHero(
            controller: _summaryCtrl,
            chart: chart,
            onPersist: _persistSummaryOnly,
            onOpenDetails: _openThirtySecondDetails,
          ),
          _PhaseRail(current: phase, onJump: _setPhase),
          Expanded(
            child: IndexedStack(
              index: phaseIndex,
              children: [
                _ShootPhase(
                  chart: chart,
                  busy: _busy,
                  firstVisit: _isNewFlow,
                  onBefore: () => _shoot(GuideCameraKind.before),
                  onAfter: () => _shoot(GuideCameraKind.after),
                  onNext: () => _setPhase(VisitPhase.consult),
                ),
                _ConsultPhase(
                  concerns: _concerns,
                  chart: chart,
                  firstVisit: _isNewFlow,
                  onToggleConcern: (c) {
                    setState(() {
                      if (_concerns.contains(c)) {
                        _concerns.remove(c);
                      } else {
                        _concerns.add(c);
                      }
                    });
                    unawaited(_persistConcerns());
                  },
                  onOpenSurface: _openConsultSurface,
                  onNext: () => _setPhase(VisitPhase.plan),
                ),
                _PlanPhase(
                  chart: chart,
                  busy: _busy,
                  summaryController: _summaryCtrl,
                  deviceIntensityCap: widget.environmentBrief.deviceIntensityCap,
                  onSaveAndNext: ({
                    required String treatmentSummary,
                    required List<String> homeCarePrescriptions,
                    DateTime? nextVisitAt,
                  }) {
                    return _savePlanAndAdvance(
                      treatmentSummary: _summaryCtrl.text.trim().isEmpty
                          ? treatmentSummary
                          : _summaryCtrl.text.trim(),
                      homeCarePrescriptions: homeCarePrescriptions,
                      nextVisitAt: nextVisitAt,
                    );
                  },
                ),
                _ConsentPhase(
                  signatureController: _signatureController,
                  consentCare: _consentCare,
                  consentAbnormal: _consentAbnormal,
                  consentRefund: _consentRefund,
                  consentPhoto: _consentPhoto,
                  consentMarketing: _consentMarketing,
                  consentOffline: _consentOffline,
                  existingSignatureUrl: chart?.signatureUrl,
                  onCare: (v) => setState(() => _consentCare = v),
                  onAbnormal: (v) => setState(() => _consentAbnormal = v),
                  onRefund: (v) => setState(() => _consentRefund = v),
                  onPhoto: (v) => setState(() => _consentPhoto = v),
                  onMarketing: () =>
                      setState(() => _consentMarketing = !_consentMarketing),
                  onOffline: () =>
                      setState(() => _consentOffline = !_consentOffline),
                  onClearSignature: () => _signatureController.clear(),
                  onComplete: _saveConsentAndAdvance,
                  busy: _busy,
                ),
                _PublishPhase(chart: chart),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _persistConcerns() async {
    final chart = _chart;
    final customer = _customer;
    if (chart == null || customer == null) return;
    try {
      await widget.store.updateCustomerChartFields(
        chartId: chart.id,
        concernChips: _concerns.toList(),
      );
    } catch (_) {}
  }
}

class _CareSummaryHero extends StatefulWidget {
  const _CareSummaryHero({
    required this.controller,
    required this.chart,
    required this.onPersist,
    required this.onOpenDetails,
  });

  final TextEditingController controller;
  final CustomerChart? chart;
  final VoidCallback onPersist;
  final VoidCallback onOpenDetails;

  @override
  State<_CareSummaryHero> createState() => _CareSummaryHeroState();
}

class _CareSummaryHeroState extends State<_CareSummaryHero> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(covariant _CareSummaryHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  String get _photoHint {
    final before = widget.chart?.beforeImageUrl?.trim().isNotEmpty == true;
    final after = widget.chart?.afterImageUrl?.trim().isNotEmpty == true;
    if (before && after) {
      return '전후 비교 후보로 정리할 수 있어요.';
    }
    if (before || after) {
      final hasSummary = widget.controller.text.trim().isNotEmpty;
      if (!hasSummary) {
        return '사진은 저장됐어요. 오늘의 케어 요약을 먼저 남겨 보세요.';
      }
      return '사진은 필요할 때 추가할 수 있어요.';
    }
    return '사진은 필요할 때 추가할 수 있어요. 오늘의 케어 요약부터 남겨 보세요.';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: SoriTokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: SoriTokens.brand.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '오늘의 케어 요약',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: SoriTokens.brand,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '오늘 어떤 케어를 진행했나요?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: SoriTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: widget.controller,
              maxLines: 3,
              minLines: 2,
              onEditingComplete: widget.onPersist,
              onTapOutside: (_) => widget.onPersist(),
              decoration: InputDecoration(
                hintText: '한 문장으로 오늘 케어를 남겨 주세요',
                filled: true,
                fillColor: SoriTokens.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _photoHint,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: SoriTokens.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.onOpenDetails,
                style: TextButton.styleFrom(
                  foregroundColor: SoriTokens.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(48, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '더 자세히 남기기',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeepModeBanner extends StatelessWidget {
  const _DeepModeBanner({required this.mode});

  final ConsultationDeepMode mode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: VisitGlassTokens.cardDecoration(),
        child: SoriNarrativeBlock(
          headline: mode.label,
          narrative: switch (mode) {
            ConsultationDeepMode.fullDesign =>
              '신규 고객 기초 공사 설계 모드 — 딥 차트 전 모듈을 순차 진행합니다.',
            ConsultationDeepMode.shortenedSafety =>
              '안전 우선 모드 — Face Map을 생략하고 장벽·마찰 점검을 우선합니다.',
            ConsultationDeepMode.maintenance =>
              '유지 보수 트래킹 — 직전 계획·B/A 회상을 기준으로 상담합니다.',
            ConsultationDeepMode.quickChartOnly =>
              '간편 기록 모드',
          },
          icon: Icons.alt_route_rounded,
          compact: true,
        ),
      ),
    );
  }
}

class _HoldPhasePanel extends StatelessWidget {
  const _HoldPhasePanel({
    required this.chart,
    required this.onResume,
    required this.onCompleteHomeCare,
  });

  final CustomerChart? chart;
  final VoidCallback onResume;
  final VoidCallback onCompleteHomeCare;

  @override
  Widget build(BuildContext context) {
    final hasHomeCare = chart?.homeCarePrescriptions.isNotEmpty ?? false;
    return Padding(
      key: const Key('visit-hold-action-pad'),
      padding: _visitFixedActionPadding(
        context,
        existing: _kVisitPhaseGutter,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SoriNarrativeBlock(
            headline: '시술 보류',
            narrative:
                '장벽 상태로 오늘 시술을 보류합니다. 홈케어 처방은 필수로 남겨 당일 방문의 효능감을 제공하세요.',
            icon: Icons.pause_circle_outline_rounded,
          ),
          const SizedBox(height: 20),
          if (!hasHomeCare)
            const SoriNarrativeBlock(
              headline: '홈케어 처방 필요',
              narrative: 'Plan 단계에서 홈케어 태그를 최소 1개 이상 지정해 주세요.',
              icon: Icons.spa_outlined,
              compact: true,
            ),
          const Spacer(),
          FilledButton(
            onPressed: hasHomeCare ? onCompleteHomeCare : onResume,
            style: FilledButton.styleFrom(
              backgroundColor: VisitGlassTokens.care,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(hasHomeCare ? '홈케어 처방 완료 · 동의로' : 'Plan으로 이동'),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onResume, child: const Text('상담 재개')),
        ],
      ),
    );
  }
}

class _ReturningContextBanner extends StatelessWidget {
  const _ReturningContextBanner({
    required this.prior,
    required this.baWarm,
    required this.onOpenBaRecall,
  });

  final CustomerChart prior;
  final bool baWarm;
  final VoidCallback onOpenBaRecall;

  @override
  Widget build(BuildContext context) {
    final summary = prior.treatmentSummary.trim();
    final insight = prior.directorInsight.trim();
    final planText = summary.isNotEmpty
        ? summary
        : (insight.isNotEmpty ? insight : '직전 회차 기록 없음');
    final rx = HomecareDictionary.sanitizeTagIds(prior.homeCarePrescriptions);

    return Material(
      color: const Color(0xFF1C1C1E),
      child: InkWell(
        onTap: onOpenBaRecall,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: SoriTokens.border),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '직전 관리 계획 · BaRecall',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white70,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  if (baWarm)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'B/A 준비됨',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.photo_library_outlined,
                    color: Colors.white70,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${prior.visitNumber}회차 — $planText',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: Colors.white,
                ),
              ),
              if (rx.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: rx
                      .map(
                        (id) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Text(
                            HomecareDictionary.chipLabelOf(id) ?? id,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                '지난번에 말씀드린 대로 오늘 관리를 이어갑니다. 탭하여 과거 B/A 확인',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.55),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewCustomerOnboardingBanner extends StatelessWidget {
  const _NewCustomerOnboardingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      color: SoriTokens.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '첫 방문 상담 가이드',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const _OnboardStep(
            index: '1',
            label: '고민 부위 · 피부 상태 칩 기록',
          ),
          const SizedBox(height: 4),
          const _OnboardStep(
            index: '2',
            label: '1회차 Before 촬영',
          ),
          const SizedBox(height: 4),
          const _OnboardStep(
            index: '3',
            label: '상담 · 관리 계획 · 동의서',
          ),
        ],
      ),
    );
  }
}

class _OnboardStep extends StatelessWidget {
  const _OnboardStep({required this.index, required this.label});

  final String index;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SoriTokens.primary,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            index,
            style: const TextStyle(
              color: SoriTokens.onPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: SoriTokens.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _PhaseRail extends StatelessWidget {
  const _PhaseRail({required this.current, required this.onJump});

  final VisitPhase current;
  final ValueChanged<VisitPhase> onJump;

  @override
  Widget build(BuildContext context) {
    final phases = VisitPhase.workflow;
    final currentIdx = current == VisitPhase.done
        ? phases.length
        : current.workflowIndex;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          for (var i = 0; i < phases.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= currentIdx
                      ? SoriTokens.brand.withValues(alpha: 0.35)
                      : SoriTokens.border,
                ),
              ),
            _PhaseDot(
              label: phases[i].label,
              active: phases[i] == current,
              done: i < currentIdx,
              onTap: i <= currentIdx ? () => onJump(phases[i]) : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanPhase extends StatefulWidget {
  const _PlanPhase({
    required this.chart,
    required this.busy,
    required this.summaryController,
    required this.onSaveAndNext,
    this.deviceIntensityCap = 4,
  });

  final CustomerChart? chart;
  final bool busy;
  final TextEditingController summaryController;
  final int deviceIntensityCap;
  final Future<void> Function({
    required String treatmentSummary,
    required List<String> homeCarePrescriptions,
    DateTime? nextVisitAt,
  }) onSaveAndNext;

  @override
  State<_PlanPhase> createState() => _PlanPhaseState();
}

class _PlanPhaseState extends State<_PlanPhase> {
  late final Set<String> _prescriptions;
  DateTime? _nextVisitAt;
  bool _detailsOpen = false;

  @override
  void initState() {
    super.initState();
    _prescriptions = {
      ...HomecareDictionary.sanitizeTagIds(
        widget.chart?.homeCarePrescriptions ?? const [],
      ),
    };
  }

  Future<void> _pickNextVisit() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _nextVisitAt ?? now.add(const Duration(days: 28)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: '다음 방문 일정',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _nextVisitAt ?? DateTime(now.year, now.month, now.day, 14),
      ),
    );
    if (!mounted) return;
    setState(() {
      _nextVisitAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 14,
        time?.minute ?? 0,
      );
    });
  }

  String _fmtNext(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('visit-phase-list'),
      padding: _visitPhaseListPadding(context),
      children: [
        Text(
          '다음 관리',
          style: VisitGlassTokens.displayKpi(context).copyWith(fontSize: 20),
        ),
        const SizedBox(height: 6),
        Text(
          '요약을 확인한 뒤, 필요할 때만 홈케어·다음 일정을 남겨 주세요.',
          style: VisitGlassTokens.bodyCalm.copyWith(
            color: SoriTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        if (widget.deviceIntensityCap < 4)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: VisitGlassTokens.cardDecoration(),
              child: SoriNarrativeBlock(
                headline: '환경 기반 강도 상한',
                narrative:
                    '오늘 피부 스트레스로 장비·HIFU 출력은 Level ${widget.deviceIntensityCap} 이하로 제한합니다.',
                icon: Icons.tune_rounded,
                compact: true,
              ),
            ),
          ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: false,
            onExpansionChanged: (v) => setState(() => _detailsOpen = v),
            tilePadding: EdgeInsets.zero,
            title: Text(
              _detailsOpen ? '상세 접기' : '더 자세히 남기기',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: SoriTokens.textSecondary,
              ),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '홈케어 처방',
                  style: VisitGlassTokens.captionCalm.copyWith(
                    color: VisitGlassTokens.care,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in HomecareDictionary.allTagIds)
                    FilterChip(
                      label: Text(HomecareDictionary.chipLabelOf(id) ?? id),
                      selected: _prescriptions.contains(id),
                      onSelected: (sel) {
                        setState(() {
                          if (sel) {
                            _prescriptions.add(id);
                          } else {
                            _prescriptions.remove(id);
                          }
                        });
                      },
                      selectedColor:
                          VisitGlassTokens.sage.withValues(alpha: 0.25),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '다음 방문 일정',
                  style: VisitGlassTokens.captionCalm.copyWith(
                    color: VisitGlassTokens.care,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              VisitGlassCard(
                onTap: widget.busy ? null : _pickNextVisit,
                child: Row(
                  children: [
                    Icon(
                      Icons.event_available_rounded,
                      color: VisitGlassTokens.care,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _nextVisitAt == null
                            ? '선택 (선택 사항)'
                            : _fmtNext(_nextVisitAt!),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _nextVisitAt == null
                              ? SoriTokens.textSecondary
                              : SoriTokens.textPrimary,
                        ),
                      ),
                    ),
                    if (_nextVisitAt != null)
                      IconButton(
                        onPressed: widget.busy
                            ? null
                            : () => setState(() => _nextVisitAt = null),
                        icon: const Icon(Icons.clear_rounded, size: 18),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: widget.busy
              ? null
              : () => widget.onSaveAndNext(
                    treatmentSummary: widget.summaryController.text.trim(),
                    homeCarePrescriptions: _prescriptions.toList(),
                    nextVisitAt: _nextVisitAt,
                  ),
          style: FilledButton.styleFrom(
            backgroundColor: SoriTokens.brand,
            foregroundColor: SoriTokens.onBrand,
            minimumSize: const Size.fromHeight(48),
          ),
          child: widget.busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('저장 후 기록 확인으로 이동'),
        ),
      ],
    );
  }
}

class _PhaseDot extends StatelessWidget {
  const _PhaseDot({
    required this.label,
    required this.active,
    required this.done,
    this.onTap,
  });

  final String label;
  final bool active;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active || done ? SoriTokens.brand : SoriTokens.border;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? SoriTokens.brand.withValues(alpha: 0.25)
                  : Colors.transparent,
              border: Border.all(color: color, width: 2),
            ),
            child: done
                ? const Icon(Icons.check, size: 16, color: SoriTokens.brand)
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: VisitGlassTokens.captionCalm.copyWith(
              color: active ? SoriTokens.brand : SoriTokens.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShootPhase extends StatelessWidget {
  const _ShootPhase({
    required this.chart,
    required this.busy,
    required this.firstVisit,
    required this.onBefore,
    required this.onAfter,
    required this.onNext,
  });

  final CustomerChart? chart;
  final bool busy;
  final bool firstVisit;
  final VoidCallback onBefore;
  final VoidCallback onAfter;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final before = chart?.beforeImageUrl;
    final after = chart?.afterImageUrl;

    return ListView(
      key: const Key('visit-phase-list'),
      padding: _visitPhaseListPadding(context),
      children: [
        Text(
          '사진과 변화 기록',
          style: VisitGlassTokens.displayKpi(context).copyWith(fontSize: 20),
        ),
        const SizedBox(height: 6),
        Text(
          '사진은 필요할 때 추가할 수 있어요.',
          style: VisitGlassTokens.bodyCalm.copyWith(
            color: SoriTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        if (firstVisit) ...[
          _PhotoSlot(
            label: '전 · 첫 방문',
            url: before,
            onShoot: busy ? null : onBefore,
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: 0.55,
            child: _PhotoSlot(
              label: '후 · 관리 후',
              url: after,
              onShoot: null,
              subtitle: '오늘 관리 후 촬영',
            ),
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: _PhotoSlot(
                  label: '전',
                  url: before,
                  onShoot: busy ? null : onBefore,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PhotoSlot(
                  label: '후',
                  url: after,
                  onShoot: busy ? null : onAfter,
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onNext,
          style: FilledButton.styleFrom(
            backgroundColor: SoriTokens.brand,
            foregroundColor: SoriTokens.onBrand,
            minimumSize: const Size.fromHeight(48),
          ),
          child: Text(firstVisit ? '고객 이야기로 이동' : '고객 이야기로 이동'),
        ),
      ],
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.label,
    required this.url,
    this.onShoot,
    this.subtitle,
  });

  final String label;
  final String? url;
  final VoidCallback? onShoot;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url?.trim().isNotEmpty == true;
    return VisitGlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: hasUrl
                  ? CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover)
                  : Container(
                      color: VisitGlassTokens.careSoft.withValues(alpha: 0.5),
                      child: Icon(
                        Icons.photo_camera_outlined,
                        color: VisitGlassTokens.care.withValues(alpha: 0.6),
                        size: 36,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 11,
                color: SoriTokens.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (onShoot != null)
            OutlinedButton(
              onPressed: onShoot,
              child: Text(hasUrl ? '다시 촬영' : '촬영'),
            ),
        ],
      ),
    );
  }
}

class _ConsultPhase extends StatelessWidget {
  const _ConsultPhase({
    required this.concerns,
    required this.chart,
    required this.firstVisit,
    required this.onToggleConcern,
    required this.onOpenSurface,
    required this.onNext,
  });

  final Set<String> concerns;
  final CustomerChart? chart;
  final bool firstVisit;
  final ValueChanged<String> onToggleConcern;
  final VoidCallback onOpenSurface;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('visit-phase-list'),
      padding: _visitPhaseListPadding(context),
      children: [
        Text(
          '고객 이야기',
          style: VisitGlassTokens.displayKpi(context).copyWith(fontSize: 20),
        ),
        const SizedBox(height: 6),
        Text(
          '상단「더 자세히 남기기」에서 이야기·관찰을 남길 수 있어요. 필요할 때만 대면 상담을 여세요.',
          style: VisitGlassTokens.bodyCalm.copyWith(
            color: SoriTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        VisitGlassCard(
          socialGlow: true,
          onTap: onOpenSurface,
          child: Row(
            children: [
              Icon(Icons.tablet_mac_rounded, color: VisitGlassTokens.care),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '고객 대면 상담 화면',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '함께 보는 co-view 열기',
                      style: VisitGlassTokens.captionCalm.copyWith(
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_rounded),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: EdgeInsets.zero,
            title: Text(
              concerns.isEmpty
                  ? '상태 칩 보조 보기'
                  : '상태 칩 보조 보기 (${concerns.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: SoriTokens.textSecondary,
              ),
            ),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ChartInterviewChips.skinConcerns.map((c) {
                  final selected = concerns.contains(c);
                  return FilterChip(
                    label: Text(c),
                    selected: selected,
                    onSelected: (_) => onToggleConcern(c),
                    selectedColor: VisitGlassTokens.care.withValues(alpha: 0.25),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onNext,
          style: FilledButton.styleFrom(
            backgroundColor: SoriTokens.brand,
            foregroundColor: SoriTokens.onBrand,
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('다음 관리로 이동'),
        ),
      ],
    );
  }
}

class _ConsentPhase extends StatelessWidget {
  const _ConsentPhase({
    required this.signatureController,
    required this.consentCare,
    required this.consentAbnormal,
    required this.consentRefund,
    required this.consentPhoto,
    required this.consentMarketing,
    required this.consentOffline,
    required this.onCare,
    required this.onAbnormal,
    required this.onRefund,
    required this.onPhoto,
    required this.onMarketing,
    required this.onOffline,
    required this.onClearSignature,
    required this.onComplete,
    required this.busy,
    this.existingSignatureUrl,
  });

  final SignatureController signatureController;
  final bool consentCare;
  final bool consentAbnormal;
  final bool consentRefund;
  final bool consentPhoto;
  final bool consentMarketing;
  final bool consentOffline;
  final String? existingSignatureUrl;
  final ValueChanged<bool> onCare;
  final ValueChanged<bool> onAbnormal;
  final ValueChanged<bool> onRefund;
  final ValueChanged<bool> onPhoto;
  final VoidCallback onMarketing;
  final VoidCallback onOffline;
  final VoidCallback onClearSignature;
  final VoidCallback onComplete;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ChartConsentTab(
            consentCareNotice: consentCare,
            consentAbnormalReaction: consentAbnormal,
            consentRefundPolicy: consentRefund,
            consentPhoto: consentPhoto,
            consentMarketing: consentMarketing,
            consentOfflineOnly: consentOffline,
            signatureController: signatureController,
            onCareNoticeChanged: onCare,
            onAbnormalReactionChanged: onAbnormal,
            onRefundPolicyChanged: onRefund,
            onPhotoChanged: onPhoto,
            onMarketingSelected: onMarketing,
            onOfflineOnlySelected: onOffline,
            onClearSignature: onClearSignature,
            existingSignatureUrl: existingSignatureUrl,
          ),
        ),
        Padding(
          key: const Key('visit-consent-action-pad'),
          padding: _visitFixedActionPadding(
            context,
            existing: _kVisitConsentActionPad,
          ),
          child: FilledButton(
            onPressed: busy ? null : onComplete,
            style: FilledButton.styleFrom(
              backgroundColor: SoriTokens.brand,
              foregroundColor: SoriTokens.onBrand,
              minimumSize: const Size.fromHeight(48),
            ),
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('서명 완료 · 기록 마무리'),
          ),
        ),
      ],
    );
  }
}

class _PublishPhase extends StatelessWidget {
  const _PublishPhase({required this.chart});

  final CustomerChart? chart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          '동의서 완료 후 기록 마무리에서\n커뮤니티 발행 항목을 선택할 수 있어요.',
          textAlign: TextAlign.center,
          style: VisitGlassTokens.bodyCalm.copyWith(
            color: SoriTokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
