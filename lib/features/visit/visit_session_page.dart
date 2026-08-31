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
import '../../views/chart_consent_tab.dart';
import '../../views/smart_guide_camera_page.dart';
import '../../visit_kernel/models/visit_session.dart';
import '../../visit_kernel/theme/visit_glass_tokens.dart';
import '../../visit_kernel/visit_store.dart';
import '../../visit_kernel/widgets/visit_glass_widgets.dart';
import 'ba_recall_cache.dart';
import 'ba_recall_overlay.dart';
import 'consultation_surface_page.dart';

/// Visit Session — Shoot → Consult → Plan → Consent → Publish (PRD v3.1).
class VisitSessionPage extends StatefulWidget {
  const VisitSessionPage({
    super.key,
    required this.store,
    required this.sessionId,
  });

  final SoriStore store;
  final String sessionId;

  @override
  State<VisitSessionPage> createState() => _VisitSessionPageState();
}

class _VisitSessionPageState extends State<VisitSessionPage> {
  late final SignatureController _signatureController;
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

  /// Prior visits exist (excluding today's session draft).
  bool get _isReturningCustomer {
    final customer = _customer;
    if (customer == null) return false;
    final currentId = _chart?.id;
    return widget.store
        .chartsForCustomer(customer.id)
        .any((c) => c.id != currentId);
  }

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
    widget.store.addListener(_onStore);
    _hydrateFromChart();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isReturningCustomer) unawaited(_prefetchBaRecall());
    });
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    _signatureController.dispose();
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
        treatmentSummary: chart.treatmentSummary,
        directorInsight: chart.directorInsight,
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('오늘의 방문이 완료되었습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
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
    final phaseIndex = phase == VisitPhase.done
        ? VisitPhase.workflow.length - 1
        : phase.workflowIndex.clamp(0, VisitPhase.workflow.length - 1);
    final showBaPill =
        _isReturningCustomer &&
        (phase == VisitPhase.consult || phase == VisitPhase.plan);
    final prior = _lastPriorChart;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text(
          _isReturningCustomer
              ? '${customer.name}님 · 재방문 상담'
              : '${customer.name}님 · 첫 상담',
        ),
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
      ),
      floatingActionButton: showBaPill
          ? FloatingActionButton.extended(
              onPressed: _openBaRecall,
              backgroundColor: SoriTokens.primary,
              foregroundColor: SoriTokens.onPrimary,
              icon: Icon(
                Icons.photo_library_outlined,
                color: _baWarm ? SoriTokens.textSecondary : SoriTokens.onPrimary,
              ),
              label: Text(_baWarm ? '과거 B/A · 즉시' : '과거 B/A'),
            )
          : null,
      body: Column(
        children: [
          if (_isReturningCustomer && prior != null)
            _ReturningContextBanner(
              prior: prior,
              baWarm: _baWarm,
              onOpenBaRecall: _openBaRecall,
            ),
          if (!_isReturningCustomer)
            const _NewCustomerHintBanner(),
          _PhaseRail(current: phase, onJump: _setPhase),
          Expanded(
            child: IndexedStack(
              index: phaseIndex,
              children: [
                _ShootPhase(
                  chart: chart,
                  busy: _busy,
                  onBefore: () => _shoot(GuideCameraKind.before),
                  onAfter: () => _shoot(GuideCameraKind.after),
                  onNext: () => _setPhase(VisitPhase.consult),
                ),
                _ConsultPhase(
                  concerns: _concerns,
                  chart: chart,
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
                  onSaveAndNext: _savePlanAndAdvance,
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
    final preview = summary.isNotEmpty
        ? summary
        : (insight.isNotEmpty ? insight : '직전 회차 기록 없음');

    return Material(
      color: SoriTokens.surface,
      child: InkWell(
        onTap: onOpenBaRecall,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: SoriTokens.border),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '직전 ${prior.visitNumber}회차 요약',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    if (baWarm) ...[
                      const SizedBox(height: 4),
                      const Text(
                        '과거 B/A 준비됨',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: SoriTokens.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.photo_library_outlined,
                color: SoriTokens.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewCustomerHintBanner extends StatelessWidget {
  const _NewCustomerHintBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: SoriTokens.surface,
        border: Border(
          bottom: BorderSide(color: SoriTokens.border),
        ),
      ),
      child: const Text(
        '첫 상담입니다. 고객 상태 칩부터 차근차근 기록해 주세요.',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: SoriTokens.textSecondary,
          height: 1.35,
        ),
      ),
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
                      ? SoriTokens.primary.withValues(alpha: 0.35)
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
    required this.onSaveAndNext,
  });

  final CustomerChart? chart;
  final bool busy;
  final Future<void> Function({
    required String treatmentSummary,
    required List<String> homeCarePrescriptions,
    DateTime? nextVisitAt,
  }) onSaveAndNext;

  @override
  State<_PlanPhase> createState() => _PlanPhaseState();
}

class _PlanPhaseState extends State<_PlanPhase> {
  late final TextEditingController _summaryCtrl;
  late final Set<String> _prescriptions;
  DateTime? _nextVisitAt;

  @override
  void initState() {
    super.initState();
    _summaryCtrl = TextEditingController(
      text: widget.chart?.treatmentSummary.trim() ?? '',
    );
    _prescriptions = {
      ...HomecareDictionary.sanitizeTagIds(
        widget.chart?.homeCarePrescriptions ?? const [],
      ),
    };
  }

  @override
  void dispose() {
    _summaryCtrl.dispose();
    super.dispose();
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
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '관리 계획',
          style: VisitGlassTokens.displayKpi(context).copyWith(fontSize: 22),
        ),
        const SizedBox(height: 8),
        Text(
          '상담을 바탕으로 앞으로의 케어 플랜을 정리하고 차트에 저장해요.',
          style: VisitGlassTokens.bodyCalm.copyWith(
            color: SoriTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '홈케어 처방',
          style: VisitGlassTokens.captionCalm.copyWith(
            color: VisitGlassTokens.care,
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
                selectedColor: VisitGlassTokens.sage.withValues(alpha: 0.25),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          '관리 요약',
          style: VisitGlassTokens.captionCalm.copyWith(
            color: VisitGlassTokens.care,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _summaryCtrl,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: '다음 관리 방향, 회차별 목표를 적어 주세요',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.72),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '다음 방문 일정',
          style: VisitGlassTokens.captionCalm.copyWith(
            color: VisitGlassTokens.care,
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
        const SizedBox(height: 24),
        FilledButton(
          onPressed: widget.busy
              ? null
              : () => widget.onSaveAndNext(
                    treatmentSummary: _summaryCtrl.text.trim(),
                    homeCarePrescriptions: _prescriptions.toList(),
                    nextVisitAt: _nextVisitAt,
                  ),
          style: FilledButton.styleFrom(
            backgroundColor: VisitGlassTokens.care,
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
              : const Text('저장 후 동의서로 이동'),
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
    final color = active || done ? VisitGlassTokens.care : SoriTokens.border;
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
                  ? VisitGlassTokens.care.withValues(alpha: 0.25)
                  : Colors.transparent,
              border: Border.all(color: color, width: 2),
            ),
            child: done
                ? Icon(Icons.check, size: 16, color: VisitGlassTokens.care)
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: VisitGlassTokens.captionCalm.copyWith(
              color: active ? VisitGlassTokens.care : SoriTokens.textSecondary,
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
    required this.onBefore,
    required this.onAfter,
    required this.onNext,
  });

  final CustomerChart? chart;
  final bool busy;
  final VoidCallback onBefore;
  final VoidCallback onAfter;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final before = chart?.beforeImageUrl;
    final after = chart?.afterImageUrl;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'SORI 카메라로 기록',
          style: VisitGlassTokens.displayKpi(context).copyWith(fontSize: 22),
        ),
        const SizedBox(height: 8),
        Text(
          '촬영한 사진은 차트에 자동으로 연결됩니다.',
          style: VisitGlassTokens.bodyCalm.copyWith(
            color: SoriTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _PhotoSlot(
                label: 'Before',
                url: before,
                onShoot: busy ? null : onBefore,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PhotoSlot(
                label: 'After',
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
            backgroundColor: VisitGlassTokens.care,
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('상담으로 이동'),
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
  });

  final String label;
  final String? url;
  final VoidCallback? onShoot;

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
          const SizedBox(height: 8),
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
    required this.onToggleConcern,
    required this.onOpenSurface,
    required this.onNext,
  });

  final Set<String> concerns;
  final CustomerChart? chart;
  final ValueChanged<String> onToggleConcern;
  final VoidCallback onOpenSurface;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '함께 상태 확인',
          style: VisitGlassTokens.displayKpi(context).copyWith(fontSize: 22),
        ),
        const SizedBox(height: 8),
        Text(
          '고객님과 나란히 볼 수 있는 화면을 띄워 소통해 보세요.',
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
        const SizedBox(height: 20),
        Text(
          '상태 칩',
          style: VisitGlassTokens.captionCalm.copyWith(
            color: VisitGlassTokens.care,
          ),
        ),
        const SizedBox(height: 10),
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
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onNext,
          style: FilledButton.styleFrom(
            backgroundColor: VisitGlassTokens.care,
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('관리 계획 작성 →'),
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
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: busy ? null : onComplete,
            style: FilledButton.styleFrom(
              backgroundColor: VisitGlassTokens.care,
              minimumSize: const Size.fromHeight(48),
            ),
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('서명 완료 · 발행 준비'),
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
          '동의서 완료 후 Publish Rail에서\nWhisper · Tip · B/A · Mentoring을 한 번에 발행할 수 있어요.',
          textAlign: TextAlign.center,
          style: VisitGlassTokens.bodyCalm.copyWith(
            color: SoriTokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
