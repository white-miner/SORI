import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('visit complete offers schedule-next via existing addManualCareSchedule', () {
    final src =
        File('lib/features/visit/visit_session_page.dart').readAsStringSync();
    expect(src.contains("enum _VisitCompleteChoice { customerDetail, nextSchedule, scheduleNext, close }"), isTrue);
    expect(src.contains("key: const Key('visit-complete-schedule-next')"), isTrue);
    expect(src.contains("child: const Text('다음 케어 일정 잡기')"), isTrue);
    expect(src.contains('_pickNextCareDateTime'), isTrue);
    expect(src.contains('await widget.store.addManualCareSchedule('), isTrue);
    expect(src.contains("helpText: '다음 방문 일정'"), isTrue);
    expect(src.contains('Never auto-jump to Home'), isTrue);
    expect(src.contains('_VisitCompleteChoice.nextSchedule'), isTrue);
    expect(src.contains('_VisitCompleteChoice.customerDetail'), isTrue);
  });

  test('SoriStore.addManualCareSchedule remains the create path', () {
    final src = File('lib/services/sori_store.dart').readAsStringSync();
    expect(
      src.contains(
        'Future<CareScheduleEntry> addManualCareSchedule({',
      ),
      isTrue,
    );
    expect(src.contains('upsertCareScheduleEntry(entry)'), isTrue);
  });
}
