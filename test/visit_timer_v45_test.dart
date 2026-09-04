import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/operation/visit_timer_store.dart';
import 'package:sori/visit_kernel/models/care_program_template.dart';
import 'package:sori/visit_kernel/models/preset_slot_tint.dart';
import 'package:sori/visit_kernel/models/visit_operation_timer.dart';

void main() {
  group('VisitTimerLiveSnapshot', () {
    test('computes total and chart seconds during consulting', () {
      final started = DateTime(2026, 8, 31, 10, 0, 0);
      final now = started.add(const Duration(minutes: 5, seconds: 30));
      final timer = VisitOperationTimer(
        id: 't1',
        visitSessionId: 's1',
        shopId: 'shop1',
        consultationStartedAt: started,
        chartOpenedAt: started.add(const Duration(minutes: 2)),
        chartActiveSeconds: 60,
        status: VisitTimerStatus.consulting,
      );

      final snap = VisitTimerLiveSnapshot.compute(timer, now: now);

      expect(snap.totalSeconds, 330);
      expect(snap.chartSeconds, 270);
      expect(snap.careSeconds, 0);
    });

    test('step remaining counts down during care', () {
      final careStart = DateTime(2026, 8, 31, 11, 0, 0);
      final timer = VisitOperationTimer(
        id: 't2',
        visitSessionId: 's2',
        shopId: 'shop1',
        consultationStartedAt: careStart.subtract(const Duration(minutes: 20)),
        careStartedAt: careStart,
        currentStepIndex: 0,
        currentStepStartedAt: careStart,
        templateSnapshot: const [
          CareProgramStep(label: '클렌징', minutes: 10),
          CareProgramStep(label: '마사지', minutes: 15),
        ],
        status: VisitTimerStatus.care,
      );

      final snap = VisitTimerLiveSnapshot.compute(
        timer,
        now: careStart.add(const Duration(minutes: 3)),
      );

      expect(snap.currentStepLabel, '클렌징');
      expect(snap.currentStepRemainingSeconds, 7 * 60);
      expect(snap.isOvertime, isFalse);
    });

    test('canEndCare allows early exit during active care', () {
      final timer = VisitOperationTimer(
        id: 't2b',
        visitSessionId: 's2b',
        shopId: 'shop1',
        careStartedAt: DateTime(2026, 8, 31, 11),
        currentStepIndex: 0,
        templateSnapshot: const [
          CareProgramStep(label: '클렌징', minutes: 10),
        ],
        status: VisitTimerStatus.care,
      );
      expect(timer.canEndCare, isTrue);
    });

    test('overtime flag after preset complete', () {
      final timer = VisitOperationTimer(
        id: 't3',
        visitSessionId: 's3',
        shopId: 'shop1',
        careStartedAt: DateTime(2026, 8, 31, 12),
        status: VisitTimerStatus.careOvertime,
      );

      final snap = VisitTimerLiveSnapshot.compute(timer);
      expect(snap.isOvertime, isTrue);
      expect(snap.currentStepLabel, '오버타임');
    });

    test('plan remaining is current leftover plus later steps', () {
      final careStart = DateTime(2026, 8, 31, 11, 0, 0);
      final timer = VisitOperationTimer(
        id: 't4',
        visitSessionId: 's4',
        shopId: 'shop1',
        careStartedAt: careStart,
        currentStepIndex: 0,
        currentStepStartedAt: careStart,
        templateSnapshot: const [
          CareProgramStep(label: '클렌징', minutes: 10),
          CareProgramStep(label: '마사지', minutes: 15),
        ],
        status: VisitTimerStatus.care,
      );

      final snap = VisitTimerLiveSnapshot.compute(
        timer,
        now: careStart.add(const Duration(minutes: 3)),
      );

      expect(snap.planRemainingSeconds, 7 * 60 + 15 * 60);
      expect(snap.displaySeconds, snap.planRemainingSeconds);
      expect(snap.remainingLabel, '종료까지 남은 시간');
      expect(snap.isOvertime, isFalse);
    });

    test('overtime counts up after plan remaining hits zero', () {
      final careStart = DateTime(2026, 8, 31, 12, 0, 0);
      const planned = 10 * 60;
      final timer = VisitOperationTimer(
        id: 't5',
        visitSessionId: 's5',
        shopId: 'shop1',
        careStartedAt: careStart,
        templateSnapshot: const [
          CareProgramStep(label: '클렌징', minutes: 10),
        ],
        status: VisitTimerStatus.careOvertime,
      );

      final snap = VisitTimerLiveSnapshot.compute(
        timer,
        now: careStart.add(Duration(seconds: planned + 12)),
      );

      expect(snap.isOvertime, isTrue);
      expect(snap.planRemainingSeconds, 0);
      expect(snap.overtimeElapsedSeconds, 12);
      expect(snap.displaySeconds, 12);
      expect(snap.remainingLabel, '추가 시간');
      expect(snap.formatKoreanClock(12), '0분 12초');
    });
  });

  group('VisitTimerStore skip', () {
    test('skipToNextStep discards remaining and opens the next block', () async {
      final store = VisitTimerStore.instance;
      final start = DateTime.now();
      store.carePaused = false;
      store.active = VisitOperationTimer(
        id: 'skip-1',
        visitSessionId: '',
        shopId: '',
        careStartedAt: start,
        currentStepIndex: 0,
        currentStepStartedAt: start,
        templateSnapshot: const [
          CareProgramStep(label: '클렌징', minutes: 10),
          CareProgramStep(label: '마사지', minutes: 5),
        ],
        status: VisitTimerStatus.care,
      );

      expect(store.canSkipStep, isTrue);
      await store.skipToNextStep();

      expect(store.active!.currentStepIndex, 1);
      expect(store.active!.status, VisitTimerStatus.care);
      expect(store.isCareRunning, isTrue);
    });

    test('skip on last step enters overtime and keeps running', () async {
      final store = VisitTimerStore.instance;
      final start = DateTime.now();
      store.carePaused = false;
      store.active = VisitOperationTimer(
        id: 'skip-2',
        visitSessionId: '',
        shopId: '',
        careStartedAt: start,
        currentStepIndex: 1,
        currentStepStartedAt: start,
        templateSnapshot: const [
          CareProgramStep(label: '클렌징', minutes: 10),
          CareProgramStep(label: '마사지', minutes: 5),
        ],
        status: VisitTimerStatus.care,
      );

      await store.skipToNextStep();

      expect(store.active!.status, VisitTimerStatus.careOvertime);
      expect(store.isCareRunning, isTrue);
      expect(store.canSkipStep, isFalse);
    });
  });

  group('VisitTimerStore preset slots', () {
    test('presetAt returns empty template for unset slot', () {
      final store = VisitTimerStore.instance;
      store.presets = const [];
      final preset = store.presetAt(2);
      expect(preset.slotIndex, 2);
      expect(preset.isEmpty, isTrue);
    });
  });

  group('CareProgramTemplate', () {
    test('round-trips json steps and slot tint', () {
      const template = CareProgramTemplate(
        id: 'p1',
        shopId: 'shop1',
        slotIndex: 0,
        name: '기본',
        slotTint: PresetSlotTint.orange,
        steps: [
          CareProgramStep(label: 'A', minutes: 5),
          CareProgramStep(label: 'B', minutes: 10),
        ],
      );

      final restored = CareProgramTemplate.fromMap(template.toMap());
      expect(restored.name, '기본');
      expect(restored.slotTint, PresetSlotTint.orange);
      expect(restored.steps.length, 2);
      expect(restored.steps.first.seconds, 300);
    });
  });
}
