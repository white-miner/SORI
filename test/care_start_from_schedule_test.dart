import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/operation/visit_timer_store.dart';
import 'package:sori/features/visit/care_start_from_schedule.dart';
import 'package:sori/visit_kernel/models/visit_operation_timer.dart';

void main() {
  tearDown(() {
    VisitTimerStore.instance.active = null;
  });

  test('timerBusy false when no active', () {
    VisitTimerStore.instance.active = null;
    expect(CareStartFromSchedule.timerBusy, isFalse);
  });

  test('timerBusy true when care running status', () {
    VisitTimerStore.instance.active = VisitOperationTimer(
      id: 't1',
      visitSessionId: 's1',
      shopId: 'shop',
      status: VisitTimerStatus.care,
    );
    expect(CareStartFromSchedule.timerBusy, isTrue);
  });

  test('timerBusy false when done', () {
    VisitTimerStore.instance.active = VisitOperationTimer(
      id: 't1',
      visitSessionId: 's1',
      shopId: 'shop',
      status: VisitTimerStatus.done,
    );
    expect(CareStartFromSchedule.timerBusy, isFalse);
  });
}
