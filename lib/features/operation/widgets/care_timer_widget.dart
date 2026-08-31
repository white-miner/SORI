import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/sori_store.dart';
import '../../../theme/sori_tokens.dart';
import '../../../visit_kernel/models/care_program_template.dart';
import '../../../visit_kernel/models/visit_operation_timer.dart';
import '../../../visit_kernel/models/visit_session.dart';
import '../visit_timer_store.dart';
import 'care_timer_preset_editor_page.dart';
import 'flip_clock_display.dart';
import 'volume_glass_theme.dart';
import 'widget_glass_card.dart';

/// PRD v4.5 — consultation tab timer widget (flip clock + 3-button flow).
class CareTimerWidget extends StatefulWidget {
  const CareTimerWidget({
    super.key,
    required this.store,
    required this.session,
    required this.onConsultationStart,
    required this.onOpenChart,
    required this.onCareStart,
    required this.onCareEnd,
    required this.onAfterPhoto,
    required this.onVisitEnd,
  });

  final SoriStore store;
  final VisitSession session;
  final VoidCallback onConsultationStart;
  final VoidCallback onOpenChart;
  final VoidCallback onCareStart;
  final VoidCallback onCareEnd;
  final VoidCallback onAfterPhoto;
  final VoidCallback onVisitEnd;

  @override
  State<CareTimerWidget> createState() => _CareTimerWidgetState();
}

class _CareTimerWidgetState extends State<CareTimerWidget> {
  VisitTimerStore get timer => VisitTimerStore.instance;

  VisitOperationTimer? get _sessionTimer {
    final active = timer.active;
    if (active == null || active.visitSessionId != widget.session.id) {
      return null;
    }
    return active;
  }

  @override
  void initState() {
    super.initState();
    timer.addListener(_onTimer);
  }

  @override
  void dispose() {
    timer.removeListener(_onTimer);
    super.dispose();
  }

  void _onTimer() {
    if (mounted) setState(() {});
  }

  Future<void> _openPresetEditor() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CareTimerPresetEditorPage(
          store: widget.store,
          initialSlot: timer.selectedPresetSlot,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final active = _sessionTimer;
    final snap = active == null ? null : VisitTimerLiveSnapshot.compute(active);
    final customer = widget.store.findCustomer(widget.session.customerId);
    final name = customer?.name ?? widget.session.customerName;

    final displaySeconds = _displaySeconds(active, snap);
    final stepLabel = _stepLabel(active, snap);
    final subtitle = _subtitle(active, snap);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: WidgetGlassCard(
        ambientColors: const [
          Color(0xFFE8F4FD),
          Color(0xFFF4F6F9),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.nunito(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '프리셋 설정',
                  onPressed: _openPresetEditor,
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            _PresetChipRow(
              selected: timer.selectedPresetSlot,
              presets: timer.presets,
              onSelect: (i) {
                timer.selectPresetSlot(i);
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            Center(
              child: FlipClockDisplay(
                totalSeconds: displaySeconds,
                stepLabel: stepLabel,
                subtitle: subtitle,
                compact: true,
              ),
            ),
            if (snap != null) ...[
              const SizedBox(height: 10),
              _MetricRow(
                total: snap.formatDuration(snap.totalSeconds),
                chart: snap.formatDuration(snap.chartSeconds),
                care: snap.formatDuration(snap.careSeconds),
              ),
            ],
            const SizedBox(height: 14),
            ..._actionButtons(active),
            if (active?.status == VisitTimerStatus.postCare &&
                !active!.afterPhotoCaptured) ...[
              const SizedBox(height: 12),
              _AfterPhotoBanner(onCapture: widget.onAfterPhoto),
            ],
            if (active?.status == VisitTimerStatus.postCare &&
                active!.afterPhotoCaptured) ...[
              const SizedBox(height: 8),
              Text(
                '애프터 촬영 완료',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF34C759),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _displaySeconds(
    VisitOperationTimer? active,
    VisitTimerLiveSnapshot? snap,
  ) {
    if (snap == null) return 0;
    if (active?.status == VisitTimerStatus.care) {
      return snap.currentStepRemainingSeconds > 0
          ? snap.currentStepRemainingSeconds
          : snap.careSeconds;
    }
    if (active?.status == VisitTimerStatus.careOvertime) {
      return snap.careSeconds;
    }
    return snap.totalSeconds;
  }

  String? _stepLabel(
    VisitOperationTimer? active,
    VisitTimerLiveSnapshot? snap,
  ) {
    if (active == null || snap == null) return '대기';
    return switch (active.status) {
      VisitTimerStatus.consulting => '차트 작성',
      VisitTimerStatus.prep => '베드 준비',
      VisitTimerStatus.care => snap.currentStepLabel,
      VisitTimerStatus.careOvertime => '케어 종료 대기',
      VisitTimerStatus.postCare => '케어 완료',
      VisitTimerStatus.done => '방문 종료',
      _ => '상담',
    };
  }

  String? _subtitle(
    VisitOperationTimer? active,
    VisitTimerLiveSnapshot? snap,
  ) {
    if (snap == null) return '상담 시작을 눌러 차트 작성을 시작하세요';
    if (active?.status == VisitTimerStatus.careOvertime) {
      return '프리셋 완료 · 정성 시간 기록 중';
    }
    return '전체 ${snap.formatDuration(snap.totalSeconds)}';
  }

  List<Widget> _actionButtons(VisitOperationTimer? active) {
    final status = active?.status ?? VisitTimerStatus.idle;

    if (status == VisitTimerStatus.idle) {
      return [
        _PrimaryBtn(label: '상담 시작', onPressed: widget.onConsultationStart),
      ];
    }

    if (status == VisitTimerStatus.consulting ||
        status == VisitTimerStatus.prep) {
      return [
        _SecondaryBtn(label: '차트 열기', onPressed: widget.onOpenChart),
        const SizedBox(height: 8),
        _PrimaryBtn(
          label: '케어 시작',
          onPressed: timer.presetAt(timer.selectedPresetSlot).steps.isEmpty
              ? null
              : widget.onCareStart,
        ),
      ];
    }

    if (status == VisitTimerStatus.care ||
        status == VisitTimerStatus.careOvertime) {
      return [
        _PrimaryBtn(
          label: '케어 종료',
          onPressed: active!.canEndCare ? widget.onCareEnd : null,
          enabled: active.canEndCare,
        ),
      ];
    }

    if (status == VisitTimerStatus.postCare) {
      return [
        _PrimaryBtn(label: '방문 종료', onPressed: widget.onVisitEnd),
      ];
    }

    return [];
  }
}

class _PresetChipRow extends StatelessWidget {
  const _PresetChipRow({
    required this.selected,
    required this.presets,
    required this.onSelect,
  });

  final int selected;
  final List<CareProgramTemplate> presets;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(5, (i) {
          final p = i < presets.length ? presets[i] : null;
          final hasPreset = p != null && !p.isEmpty;
          final label =
              hasPreset ? p.name.trim() : '슬롯 ${i + 1}';
          final isSelected = i == selected;
          return Padding(
            padding: EdgeInsets.only(right: i < 4 ? 6 : 0),
            child: FilterChip(
              label: Text(label, overflow: TextOverflow.ellipsis),
              selected: isSelected,
              onSelected: hasPreset ? (_) => onSelect(i) : null,
              labelStyle: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : const Color(0xFF3A3A3C),
              ),
              selectedColor: SoriTokens.primary,
              backgroundColor: Colors.white.withValues(alpha: 0.85),
              showCheckmark: false,
            ),
          );
        }),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.total,
    required this.chart,
    required this.care,
  });

  final String total;
  final String chart;
  final String care;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Metric(label: '전체', value: total),
        _Metric(label: '차트', value: chart),
        _Metric(label: '케어', value: care),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: VolumeGlassTheme.labelTextStyle(compact: true),
        ),
        Text(
          value,
          style: VolumeGlassTheme.kpiTextStyle(compact: true).copyWith(
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: VolumeGlassTheme.carePrimaryButtonStyle(enabled: enabled),
        child: Text(
          label,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _SecondaryBtn extends StatelessWidget {
  const _SecondaryBtn({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          foregroundColor: SoriTokens.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              VolumeGlassTheme.cardRadius * 0.58,
            ),
          ),
          side: BorderSide.none,
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _AfterPhotoBanner extends StatelessWidget {
  const _AfterPhotoBanner({required this.onCapture});

  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius * 0.5),
        boxShadow: VolumeGlassTheme.volumeShadow(
          tint: const Color(0xFFFF9500),
          alpha: 0.05,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '케어 후 사진을 촬영해 주세요',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: onCapture,
            child: const Text('애프터 촬영'),
          ),
        ],
      ),
    );
  }
}
