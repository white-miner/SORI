import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/operation/clinical_trend_engine.dart';
import 'package:sori/features/operation/models/clinical_trend_snapshot.dart';

void main() {
  group('Clinical Trend Radar v4.3', () {
    test('rankTop3 sorts by CTI then surge then priority', () {
      final items = [
        ClinicalTrendItem.fromMap({
          'id': 'K03',
          'keyword': '트러블',
          'category': 'trouble_sebum',
          'cti': 55,
          'surge_pct': 20,
          'sparkline_7d': [30, 32, 34, 36, 38, 40, 42],
          'headline': 'h',
          'narrative': 'n',
          'po_priority': 90,
          'qualifies': true,
        }),
        ClinicalTrendItem.fromMap({
          'id': 'K01',
          'keyword': '홍조',
          'category': 'barrier_sensitive',
          'cti': 71,
          'surge_pct': 42,
          'sparkline_7d': [30, 35, 40, 45, 50, 58, 65],
          'headline': 'h',
          'narrative': 'n',
          'po_priority': 100,
          'qualifies': true,
        }),
        ClinicalTrendItem.fromMap({
          'id': 'K02',
          'keyword': '피부장벽',
          'category': 'barrier_sensitive',
          'cti': 58,
          'surge_pct': 28,
          'sparkline_7d': [30, 32, 34, 36, 38, 40, 42],
          'headline': 'h',
          'narrative': 'n',
          'po_priority': 95,
          'qualifies': true,
        }),
      ];

      final top3 = ClinicalTrendEngine.rankTop3(items);
      expect(top3.length, 3);
      expect(top3.first.keyword, '홍조');
      expect(top3[1].keyword, '피부장벽');
    });

    test('qualifiesForTop filters low-surge low-cti', () {
      expect(
        ClinicalTrendEngine.qualifiesForTop(cti: 35, surgePct: 3),
        isFalse,
      );
      expect(
        ClinicalTrendEngine.qualifiesForTop(cti: 45, surgePct: 2),
        isTrue,
      );
    });

    test('fallback snapshot has top3 and briefingLead', () {
      final snap = ClinicalTrendSnapshot.fallback();
      expect(snap.top3.length, 3);
      expect(snap.briefingLead?.keyword, '홍조');
      expect(snap.briefingLead?.narrative, isNotEmpty);
    });

    test('fromMap builds top3 when edge omits list', () {
      final snap = ClinicalTrendSnapshot.fromMap({
        'items': [
          {
            'id': 'K01',
            'keyword': '홍조',
            'category': 'barrier_sensitive',
            'cti': 70,
            'surge_pct': 40,
            'sparkline_7d': [1, 2, 3, 4, 5, 6, 7],
            'headline': 'h',
            'narrative': 'n',
            'po_priority': 100,
            'qualifies': true,
          },
        ],
      });
      expect(snap.top3.length, 1);
      expect(snap.briefingLead?.keyword, '홍조');
    });
  });
}
