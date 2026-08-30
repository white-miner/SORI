import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../content_atomizer/content_atomizer.dart';
import '../../features/publish_rail/publish_rail_sheet.dart';
import '../../models/chart_interview_chips.dart';
import '../../models/customer.dart';
import '../../models/customer_chart.dart';
import '../../services/chart_signature_storage.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../views/chart_consent_tab.dart';
import '../../views/smart_guide_camera_page.dart';
import '../../visit_kernel/models/visit_session.dart';
import '../../visit_kernel/theme/visit_glass_tokens.dart';
import '../../visit_kernel/visit_store.dart';
import '../../visit_kernel/widgets/visit_glass_widgets.dart';
import 'consultation_surface_page.dart';

/// Visit Session — Shoot → Consult → Consent → Publish (PRD v3.0 Phase 1).
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
        appBar: AppBar(title: const Text('방문')),
        body: const Center(child: Text('세션을 찾을 수 없습니다.')),
      );
    }

    final phase = session.phase;

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: Text('${customer.name}님 방문'),
        backgroundColor: SoriTokens.background,
        elevation: 0,
      ),
      body: Column(
        children: [
          _PhaseRail(current: phase, onJump: _setPhase),
          Expanded(
            child: IndexedStack(
              index: phase.index.clamp(0, 3),
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
                  onNext: () => _setPhase(VisitPhase.consent),
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

class _PhaseRail extends StatelessWidget {
  const _PhaseRail({required this.current, required this.onJump});

  final VisitPhase current;
  final ValueChanged<VisitPhase> onJump;

  @override
  Widget build(BuildContext context) {
    const phases = [
      VisitPhase.shoot,
      VisitPhase.consult,
      VisitPhase.consent,
      VisitPhase.publish,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          for (var i = 0; i < phases.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: phases[i].index <= current.index
                      ? VisitGlassTokens.care.withValues(alpha: 0.4)
                      : SoriTokens.border,
                ),
              ),
            _PhaseDot(
              label: phases[i].label,
              active: phases[i] == current,
              done: phases[i].index < current.index,
              onTap: phases[i].index <= current.index
                  ? () => onJump(phases[i])
                  : null,
            ),
          ],
        ],
      ),
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
                      'Consultation Surface',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '고객 대면 프레젠테이션 뷰 열기',
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
          child: const Text('동의서로 이동'),
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
