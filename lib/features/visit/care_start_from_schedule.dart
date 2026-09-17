import 'package:flutter/material.dart';

import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../visit_kernel/models/care_schedule_entry.dart';
import '../../visit_kernel/models/visit_operation_timer.dart';
import '../operation/care_timer_tts_service.dart';
import '../operation/visit_timer_store.dart';

/// PRD v7.9 Phase 4 — 일정 → Timer 포커스 / 케어 시작 (틱·플립시계 로직 비수정).
abstract final class CareStartFromSchedule {
  CareStartFromSchedule._();

  static String? activeTimerCustomerId(SoriStore store) {
    final active = VisitTimerStore.instance.active;
    if (active == null) return null;
    if (active.isStandalone) return null;
    final sid = active.visitSessionId.trim();
    if (sid.isEmpty) return null;
    return store.findVisitSession(sid)?.customerId.trim();
  }

  static bool get timerBusy {
    final t = VisitTimerStore.instance;
    if (t.active == null) return false;
    if (t.active!.status == VisitTimerStatus.done) return false;
    return t.isCareRunning ||
        t.isCareArmed ||
        t.active!.status == VisitTimerStatus.consulting ||
        t.active!.status == VisitTimerStatus.prep ||
        t.active!.status == VisitTimerStatus.postCare ||
        t.active!.status == VisitTimerStatus.careOvertime ||
        (t.active!.isStandalone &&
            t.active!.status != VisitTimerStatus.idle);
  }

  /// [goHomeShell]: 마이→홈 셸(0). 홈에 이미 있으면 null.
  static Future<void> begin({
    required BuildContext context,
    required SoriStore store,
    required CareScheduleEntry entry,
    VoidCallback? goHomeShell,
  }) async {
    final cid = entry.customerId?.trim() ?? '';
    if (cid.isEmpty) {
      _toast(context, '고객이 연결된 일정만 케어를 시작할 수 있어요', error: true);
      return;
    }
    if (entry.status != CareScheduleStatus.scheduled) {
      _toast(context, '예정된 일정에서만 케어를 시작할 수 있어요', error: true);
      return;
    }

    await CareTimerTtsService.primeFromUserGesture();

    if (timerBusy) {
      final activeCid = activeTimerCustomerId(store);
      final sameCustomer = activeCid != null && activeCid == cid;
      if (sameCustomer) {
        _focusTimer(store, goHomeShell: goHomeShell, startCareIfReady: false);
        return;
      }
      if (!context.mounted) return;
      final choice = await showCareStartConfirmSheet(context);
      if (!context.mounted) return;
      if (choice == CareStartConfirmChoice.viewOngoing) {
        _focusTimer(store, goHomeShell: goHomeShell, startCareIfReady: false);
        return;
      }
      if (choice != CareStartConfirmChoice.endThenStart) return;
      await _endActiveTimer();
    }

    try {
      final session = await store.startVisitSession(customerId: cid);
      await VisitTimerStore.instance.startConsultation(
        visitSessionId: session.id,
        shopId: session.shopId,
      );
      _focusTimer(
        store,
        goHomeShell: goHomeShell,
        startCareIfReady: true,
        visitSessionId: session.id,
      );
    } catch (e) {
      if (!context.mounted) return;
      _toast(context, '케어 세션을 열지 못했어요', error: true);
    }
  }

  static Future<void> _endActiveTimer() async {
    final t = VisitTimerStore.instance;
    if (t.active?.isStandalone ?? false) {
      await t.finishStandaloneCare();
      return;
    }
    if (t.active?.canEndCare ?? false) {
      await t.endCare();
    }
    if (t.active != null) {
      t.active = null;
      t.notifyListeners();
    }
  }

  static void _focusTimer(
    SoriStore store, {
    VoidCallback? goHomeShell,
    required bool startCareIfReady,
    String? visitSessionId,
  }) {
    store.requestHomeTimerFocus(
      startCareIfReady: startCareIfReady,
      visitSessionId: visitSessionId,
    );
    goHomeShell?.call();
  }

  static void _toast(BuildContext context, String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? SoriTokens.systemRed : SoriTokens.primary,
      ),
    );
  }
}

enum CareStartConfirmChoice { viewOngoing, endThenStart, dismiss }

Future<CareStartConfirmChoice?> showCareStartConfirmSheet(
  BuildContext context,
) {
  return showModalBottomSheet<CareStartConfirmChoice>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '다른 케어가 진행 중이에요',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                '새 일정의 케어를 시작하려면 진행 중 케어를 먼저 확인하거나 종료해야 해요.',
                style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  CareStartConfirmChoice.viewOngoing,
                ),
                child: const Text('진행 중인 케어 보기'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  CareStartConfirmChoice.endThenStart,
                ),
                child: const Text('종료 후 이 일정으로 시작'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  CareStartConfirmChoice.dismiss,
                ),
                child: const Text('닫기'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
