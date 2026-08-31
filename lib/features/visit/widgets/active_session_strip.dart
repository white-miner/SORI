import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/sori_store.dart';
import '../../../theme/sori_tokens.dart';
import '../../../visit_kernel/models/visit_operation_timer.dart';
import '../../../visit_kernel/models/visit_session.dart';
import '../../operation/visit_timer_store.dart';
import '../../operation/widgets/volume_glass_theme.dart';

/// PO v4.5 — main tab compact row: live total operation timer only.
class ActiveSessionStrip extends StatefulWidget {
  const ActiveSessionStrip({
    super.key,
    required this.store,
    required this.session,
    required this.onTap,
  });

  final SoriStore store;
  final VisitSession session;
  final VoidCallback onTap;

  @override
  State<ActiveSessionStrip> createState() => _ActiveSessionStripState();
}

class _ActiveSessionStripState extends State<ActiveSessionStrip> {
  VisitTimerStore get timer => VisitTimerStore.instance;

  @override
  void initState() {
    super.initState();
    timer.addListener(_onTick);
  }

  @override
  void dispose() {
    timer.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.store.findCustomer(widget.session.customerId);
    final name = customer?.name ?? widget.session.customerName;
    final timerState = _timerForSession();
    final snap = timerState == null
        ? null
        : VisitTimerLiveSnapshot.compute(timerState);
    final totalLabel =
        snap == null ? '00:00' : _formatHms(snap.totalSeconds);
    final phaseLabel = _phaseLabel(timerState);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: VolumeGlassTheme.cardFillColor(),
        elevation: 0,
        borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius),
              boxShadow: VolumeGlassTheme.volumeShadow(
                tint: VolumeGlassTheme.vibrantCareGreen,
                alpha: 0.06,
              ),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 22,
                    color: VolumeGlassTheme.vibrantCareGreen,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          phaseLabel,
                          style:
                              VolumeGlassTheme.labelTextStyle(compact: true),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    totalLabel,
                    style: VolumeGlassTheme.kpiTextStyle(compact: true)
                        .copyWith(fontSize: 22),
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
        ),
      ),
    );
  }

  VisitOperationTimer? _timerForSession() {
    final active = timer.active;
    if (active != null && active.visitSessionId == widget.session.id) {
      return active;
    }
    return null;
  }

  String _phaseLabel(VisitOperationTimer? t) {
    if (t == null) return '진행 중인 차트';
    return switch (t.status) {
      VisitTimerStatus.consulting => '차트 작성 중',
      VisitTimerStatus.prep => '케어 준비',
      VisitTimerStatus.care => '케어 진행',
      VisitTimerStatus.careOvertime => '케어 종료 대기',
      VisitTimerStatus.postCare => '케어 완료',
      VisitTimerStatus.done => '방문 종료',
      _ => '진행 중인 차트',
    };
  }

  String _formatHms(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
}
