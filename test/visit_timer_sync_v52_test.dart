import 'package:flutter_test/flutter_test.dart';

import 'package:sori/visit_kernel/models/care_program_template.dart';
import 'package:sori/visit_kernel/models/visit_operation_timer.dart';

void main() {
  group('VisitOperationTimer ephemeral fields in toMap', () {
    test('includes chart_opened_at and current_step_started_at', () {
      final opened = DateTime.utc(2026, 9, 1, 2, 0);
      final stepStart = DateTime.utc(2026, 9, 1, 2, 30);
      final timer = VisitOperationTimer(
        id: 't1',
        visitSessionId: 's1',
        shopId: 'shop1',
        chartOpenedAt: opened,
        currentStepStartedAt: stepStart,
        currentStepIndex: 1,
        templateSnapshot: const [
          CareProgramStep(label: 'A', minutes: 10),
          CareProgramStep(label: 'B', minutes: 15),
        ],
        status: VisitTimerStatus.care,
        careStartedAt: opened,
      );

      final map = timer.toMap();
      expect(map['chart_opened_at'], opened.toIso8601String());
      expect(map['current_step_started_at'], stepStart.toIso8601String());

      final restored = VisitOperationTimer.fromMap(map);
      expect(restored.chartOpenedAt?.toUtc(), opened);
      expect(restored.currentStepStartedAt?.toUtc(), stepStart);
      expect(restored.currentStepIndex, 1);
    });

    test('toLocalJson matches toMap after migration 105', () {
      final timer = VisitOperationTimer(
        id: 't2',
        visitSessionId: 's2',
        shopId: 'shop1',
        chartOpenedAt: DateTime.utc(2026, 9, 1, 3),
        currentStepStartedAt: DateTime.utc(2026, 9, 1, 3, 10),
        status: VisitTimerStatus.consulting,
      );
      expect(timer.toLocalJson(), timer.toMap());
    });
  });

  group('VisitTimerLiveSnapshot catch-up', () {
    test('step remaining stays within 1 minute after clock skew', () {
      final careStart = DateTime(2026, 9, 1, 10, 0, 0);
      final stepStart = careStart;
      final timer = VisitOperationTimer(
        id: 't3',
        visitSessionId: 's3',
        shopId: 'shop1',
        careStartedAt: careStart,
        currentStepIndex: 0,
        currentStepStartedAt: stepStart,
        templateSnapshot: const [
          CareProgramStep(label: '클렌징', minutes: 10),
        ],
        status: VisitTimerStatus.care,
      );

      final now = careStart.add(const Duration(minutes: 3, seconds: 20));
      final snap = VisitTimerLiveSnapshot.compute(timer, now: now);
      expect(snap.currentStepRemainingSeconds, 10 * 60 - (3 * 60 + 20));
      expect(snap.currentStepRemainingSeconds, lessThan(10 * 60));
      expect(
        (snap.currentStepRemainingSeconds - (6 * 60 + 40)).abs(),
        lessThan(60),
      );
    });
  });
}
