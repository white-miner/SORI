import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/operation/clinical_brief_engine.dart';
import 'package:sori/features/operation/models/clinical_environment_brief.dart';
import 'package:sori/features/operation/models/skin_stress_index.dart';
import 'package:sori/features/operation/models/shop_climate_context.dart';
import 'package:sori/features/operation/models/sos_signal.dart';
import 'package:sori/features/operation/sos_signal_parser.dart';
import 'package:sori/features/visit/consultation_track.dart';
import 'package:sori/features/operation/models/consultation_deep_mode.dart';
import 'package:sori/features/operation/models/visit_biometrics.dart';
import 'package:sori/visit_kernel/models/care_schedule_entry.dart';

void main() {
  group('SkinStressIndex v4.2', () {
    test('compute weighted SSI for hot dry UV PM scenario', () {
      final ssi = SkinStressIndex.compute(
        tempC: 33,
        humidityPct: 35,
        uvIndex: 8,
        pm25UgM3: 45,
      );
      expect(ssi.score, greaterThanOrEqualTo(60));
      expect(ssi.band, isIn([SsiBand.high, SsiBand.critical]));
    });

    test('low band for mild climate', () {
      final ssi = SkinStressIndex.compute(
        tempC: 22,
        humidityPct: 55,
        uvIndex: 2,
        pm25UgM3: 12,
      );
      expect(ssi.band, SsiBand.low);
    });
  });

  test('ShopClimateContext.fromMap builds brief + SSI', () {
    final ctx = ShopClimateContext.fromMap({
      'temp_c': 28,
      'humidity_pct': 42,
      'uv_index': 7,
      'pm25_ug_m3': 38,
      'hot_days_last_7': 2,
    });
    expect(ctx.ssi.score, greaterThan(0));
    expect(ctx.brief.calmTargetC, inInclusiveRange(20.0, 24.0));
    expect(ctx.brief.shouldSurface, isTrue);
  });

  test('ClinicalBriefEngine calm target respects dry humidity', () {
    final ssi = SkinStressIndex.compute(
      tempC: 26,
      humidityPct: 40,
      uvIndex: 3,
      pm25UgM3: 15,
    );
    final brief = ClinicalBriefEngine.build(
      tempC: 26,
      humidityPct: 40,
      uvIndex: 3,
      pm25UgM3: 15,
      ssi: ssi,
    );
    expect(brief.calmTargetC, greaterThan(22.0));
    expect(brief.narrative, isNotEmpty);
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

  test('resolveDeepMode branches returning vs safety vs SSI', () {
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
    expect(
      resolveDeepMode(
        track: ConsultationTrack.newCustomer,
        sos: SosSignal.none,
        ssiBand: SsiBand.high,
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
