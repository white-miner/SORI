import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/operation/models/shop_weather_context.dart';
import 'package:sori/features/operation/models/sos_signal.dart';
import 'package:sori/features/operation/sos_signal_parser.dart';
import 'package:sori/features/visit/consultation_track.dart';
import 'package:sori/features/operation/models/consultation_deep_mode.dart';
import 'package:sori/features/operation/models/visit_biometrics.dart';
import 'package:sori/visit_kernel/models/care_schedule_entry.dart';

void main() {
  test('ShopWeatherContext.compute calm target respects dry humidity', () {
    final ctx = ShopWeatherContext.compute(
      tempC: 26,
      humidityPct: 40,
      uvIndex: 3,
    );
    expect(ctx.calmTargetC, greaterThan(22.0));
    expect(ctx.headline, contains('초기 진정 온도'));
    expect(ctx.narrative, isNotEmpty);
  });

  test('SosSignalParser detects S3 from schedule note', () {
    final parser = SosSignalParser(mergeSosRules());
    final signal = parser.scan(
      schedule: CareScheduleEntry(
        id: 's1',
        shopId: 'shop',
        scheduledAt: DateTime.now(),
        customerName: '테스트',
        note: '활성 여드름 심함',
        status: CareScheduleStatus.scheduled,
      ),
    );
    expect(signal.grade, SosGrade.s3);
    expect(signal.headline, isNotEmpty);
  });

  test('resolveDeepMode branches returning vs safety', () {
    expect(
      resolveDeepMode(
        track: ConsultationTrack.returning,
        sos: SosSignal.none,
      ),
      ConsultationDeepMode.maintenance,
    );
    expect(
      resolveDeepMode(
        track: ConsultationTrack.newCustomer,
        sos: const SosSignal(grade: SosGrade.s3),
      ),
      ConsultationDeepMode.shortenedSafety,
    );
  });

  test('VisitBiometrics hints for alcohol active', () {
    const bio = VisitBiometrics(
      alcohol: BiometricTouchState.active,
    );
    expect(bio.hints.length, 1);
    expect(bio.hints.first.headline, contains('술'));
  });
}
