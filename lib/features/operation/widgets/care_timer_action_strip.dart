import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../visit_kernel/models/visit_operation_timer.dart';
import '../visit_timer_store.dart';
import 'volume_glass_theme.dart';

/// PRD UT-1 — 3-button flow: 상담 시작 · 케어 시작 · 케어/방문 종료.
class CareTimerActionStrip extends StatelessWidget {
  const CareTimerActionStrip({
    super.key,
    required this.timer,
    required this.onConsultationStart,
    required this.onOpenChart,
    required this.onCareStart,
    required this.onCareEnd,
    required this.onVisitEnd,
  });

  final VisitOperationTimer? timer;
  final VoidCallback onConsultationStart;
  final VoidCallback onOpenChart;
  final VoidCallback onCareStart;
  final VoidCallback onCareEnd;
  final VoidCallback onVisitEnd;

  @override
  Widget build(BuildContext context) {
    final status = timer?.status ?? VisitTimerStatus.idle;
    final store = VisitTimerStore.instance;
    final presetReady =
        store.presetAt(store.selectedPresetSlot).steps.isNotEmpty;

    if (status == VisitTimerStatus.idle) {
      return _PrimaryBtn(label: '상담 시작', onPressed: onConsultationStart);
    }

    if (status == VisitTimerStatus.consulting ||
        status == VisitTimerStatus.prep) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SecondaryBtn(label: '차트 열기', onPressed: onOpenChart),
          const SizedBox(height: 8),
          _PrimaryBtn(
            label: '케어 시작',
            onPressed: presetReady ? onCareStart : null,
            enabled: presetReady,
          ),
          if (!presetReady) ...[
            const SizedBox(height: 6),
            Text(
              '프리셋을 설정한 슬롯을 선택해 주세요',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: const Color(0xFF8E8E93),
              ),
            ),
          ],
        ],
      );
    }

    if (status == VisitTimerStatus.care ||
        status == VisitTimerStatus.careOvertime) {
      final canEnd = timer?.canEndCare ?? false;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (status == VisitTimerStatus.careOvertime)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '정성 시간 기록 중 · 종료 버튼으로 마무리',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFF9500),
                ),
              ),
            ),
          _PrimaryBtn(
            label: '케어 종료',
            onPressed: canEnd ? onCareEnd : null,
            enabled: canEnd,
          ),
        ],
      );
    }

    if (status == VisitTimerStatus.postCare) {
      return _PrimaryBtn(label: '방문 종료', onPressed: onVisitEnd);
    }

    return const SizedBox.shrink();
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
          foregroundColor: const Color(0xFF111111),
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
