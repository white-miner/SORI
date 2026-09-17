import 'package:flutter_test/flutter_test.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/models/customer_chart_tree.dart';

CustomerChart _chart({
  required String id,
  required int visitNumber,
  String careName = '테라노바 에너지 복부관리',
  String summary = '',
  String insight = '',
  String? before,
  String? after,
  DateTime? at,
}) {
  return CustomerChart(
    id: id,
    shopId: 'shop-1',
    customerId: 'cus-1',
    visitNumber: visitNumber,
    careName: careName,
    treatmentSummary: summary,
    directorInsight: insight,
    beforeImageUrl: before,
    afterImageUrl: after,
    createdAt: at ?? DateTime(2026, 8, 13),
  );
}

void main() {
  group('차트 트리 — 1고객 = 1차트, 하위 N회차', () {
    test('같은 회차의 동일 기록이 무한 증식하지 않고 한 노드로 접힌다', () {
      // image_15 재현: "1회차 · 테라노바" row가 3벌 저장된 상태.
      final file = CustomerChartFile.from(
        customerId: 'cus-1',
        charts: [
          _chart(id: 'a', visitNumber: 1),
          _chart(id: 'b', visitNumber: 1),
          _chart(id: 'c', visitNumber: 1),
        ],
      );

      expect(file.totalRounds, 1);
      expect(file.rounds.single.visitNumber, 1);
      expect(file.rounds.single.records, hasLength(1));
      expect(file.rounds.single.records.single.duplicateCount, 3);
      expect(file.rounds.single.hasBranches, isFalse);
      expect(file.collapsedDuplicateCount, 2);
    });

    test('같은 회차의 서로 다른 기록은 하위 가지로 남는다 (병합해서 지우지 않는다)', () {
      final file = CustomerChartFile.from(
        customerId: 'cus-1',
        charts: [
          _chart(id: 'a', visitNumber: 1),
          _chart(id: 'b', visitNumber: 1, careName: '전자 동의서'),
        ],
      );

      final round = file.rounds.single;
      expect(round.records, hasLength(2));
      expect(round.hasBranches, isTrue);
      expect(round.rawRecordCount, 2);
      expect(
        round.records.map((r) => r.chart.id),
        containsAll(<String>['a', 'b']),
      );
    });

    test('회차는 내림차순, 회차 번호는 고유하다', () {
      final file = CustomerChartFile.from(
        customerId: 'cus-1',
        charts: [
          _chart(id: 'r1', visitNumber: 1),
          _chart(id: 'r3', visitNumber: 3, careName: '스페셜 웨딩케어'),
          _chart(id: 'r2', visitNumber: 2, careName: '스페셜 웨딩케어'),
          _chart(id: 'r3b', visitNumber: 3, careName: '스페셜 웨딩케어'),
        ],
      );

      expect(file.rounds.map((r) => r.visitNumber), [3, 2, 1]);
      expect(
        file.rounds.map((r) => r.visitNumber).toSet(),
        hasLength(file.totalRounds),
      );
      expect(file.latestVisitNumber, 3);
    });

    test('대표 기록은 정보량이 가장 많은 row가 된다', () {
      final file = CustomerChartFile.from(
        customerId: 'cus-1',
        charts: [
          _chart(id: 'bare', visitNumber: 4, careName: '스페셜 웨딩케어'),
          _chart(
            id: 'rich',
            visitNumber: 4,
            careName: '스페셜 웨딩케어',
            summary: '부종 완화 집중',
            before: 'https://example.com/b.webp',
            after: 'https://example.com/a.webp',
          ),
        ],
      );

      final round = file.rounds.single;
      expect(round.primary.chart.id, 'rich');
      expect(round.hasAnyPhoto, isTrue);
      expect(round.isComplete, isTrue);
    });

    test('차트 번호는 고객당 고정이고 고객이 다르면 달라진다', () {
      expect(chartCodeFor('cus-1'), chartCodeFor('cus-1'));
      expect(chartCodeFor('cus-1'), isNot(chartCodeFor('cus-2')));
      expect(chartCodeFor('cus-1'), startsWith('C-'));
      expect(chartCodeFor(''), 'C-000000');
    });

    test('기록이 없으면 빈 차트철', () {
      final file = CustomerChartFile.from(customerId: 'cus-1', charts: const []);
      expect(file.isEmpty, isTrue);
      expect(file.totalRounds, 0);
      expect(file.lastVisitedAt, isNull);
      expect(file.collapsedDuplicateCount, 0);
    });

    test('최근 방문일은 가장 높은 회차의 기준 시각을 따른다', () {
      final file = CustomerChartFile.from(
        customerId: 'cus-1',
        charts: [
          _chart(id: 'r1', visitNumber: 1, at: DateTime(2026, 8, 13)),
          _chart(
            id: 'r2',
            visitNumber: 2,
            careName: '스페셜 웨딩케어',
            at: DateTime(2026, 9, 1),
          ),
        ],
      );

      expect(file.lastVisitedAt, DateTime(2026, 9, 1));
    });
  });
}
