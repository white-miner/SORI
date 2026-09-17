import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sori/features/visit/care_schedule_read_density.dart';
import 'package:sori/services/sori_store.dart';

void main() {
  test('showcase docs name the live loop routes only', () {
    final script =
        File('docs/SHOWCASE_DEMO_SCRIPT.md').readAsStringSync();
    final data = File('docs/SHOWCASE_DEMO_DATA.md').readAsStringSync();
    expect(script.contains('/#/app/home'), isTrue);
    expect(script.contains('/#/app/customers'), isTrue);
    expect(script.contains('SmartGuideCameraPage'), isTrue);
    expect(script.contains('addManualCareSchedule'), isTrue);
    expect(script.contains('CustomerCareTab'), isTrue);
    expect(script.contains('care_schedule.note'), isTrue);
    expect(data.contains('김민지'), isTrue);
    expect(data.contains('nextUpcomingForCustomer'), isTrue);
    expect(data.contains('needsAfterPhoto'), isTrue);
  });

  test('seed 김민지 reproduces B/A yes and next-care/today-schedule no', () {
    final store = SoriStore();
    final minji = store.findCustomer('1');
    expect(minji, isNotNull);
    expect(minji!.name, '김민지');

    final charts = store.chartsForCustomer('1');
    expect(charts, isNotEmpty);
    expect(
      charts.any((c) => c.hasBeforeImage && c.hasAfterImage),
      isTrue,
    );

    expect(store.careScheduleEntries, isEmpty);
    expect(
      CareScheduleReadDensity.todayScheduledSorted(store.careScheduleEntries),
      isEmpty,
    );
    expect(
      CareScheduleReadDensity.nextUpcomingForCustomer(
        store.careScheduleEntries,
        customerId: '1',
      ),
      isNull,
    );
  });
}
