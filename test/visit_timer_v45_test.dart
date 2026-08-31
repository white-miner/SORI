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
