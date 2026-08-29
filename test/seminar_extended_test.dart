import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:sori/models/seminar_class.dart';
import 'package:sori/utils/seminar_time_format.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR');
  });
  test('formatSeminarTimeRange computes end time and duration label', () {
    final start = DateTime(2026, 9, 1, 12, 44);
    final label = formatSeminarTimeRange(start: start, durationMinutes: 180);
    expect(label, contains('12:44'));
    expect(label, contains('15:44'));
    expect(label, contains('3시간'));
  });

  test('formatSeminarTimeRange handles null start', () {
    expect(
      formatSeminarTimeRange(start: null, durationMinutes: 120),
      '일정 미정',
    );
  });

  test('SeminarClass serializes extended fields for RPC payload', () {
    const cls = SeminarClass(
      id: 's1',
      directorShopId: 'shop-1',
      title: 'Live Seminar',
      targetCaseId: 'chart-1',
      durationMinutes: 150,
      providedMaterials: ['자체 제작 PPT', '디플로마'],
      additionalImages: ['https://example.com/a.jpg'],
    );

    final payload = cls.toRpcPayload(includeId: true);
    expect(payload['linked_chart_id'], 'chart-1');
    expect(payload['duration_minutes'], 150);
    expect(payload['provided_materials'], ['자체 제작 PPT', '디플로마']);
    expect(payload['additional_images'], ['https://example.com/a.jpg']);
  });

  test('SeminarClass.fromMap reads linked_chart_id alias', () {
    final cls = SeminarClass.fromMap({
      'id': 's1',
      'director_shop_id': 'shop-1',
      'linked_chart_id': 'chart-9',
      'title': 'T',
      'duration_minutes': 90,
      'provided_materials': ['실습용 색소'],
      'additional_images': [],
      'price': 0,
      'max_capacity': 12,
      'current_enrollment': 0,
      'status': 'open',
      'description': '',
      'class_format': 'oneday',
    });
    expect(cls.targetCaseId, 'chart-9');
    expect(cls.durationMinutes, 90);
    expect(cls.providedMaterials, ['실습용 색소']);
  });
}
