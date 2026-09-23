import 'package:flutter_test/flutter_test.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/utils/chart_row_collapse.dart';

CustomerChart _shell({
  required String id,
  required int visitNumber,
  required DateTime createdAt,
  String customerId = 'collapse-c',
}) {
  return CustomerChart(
    id: id,
    shopId: 'shop',
    customerId: customerId,
    visitNumber: visitNumber,
    careName: '동의',
    treatmentSummary: ChartRowCollapse.consentSummary,
    signatureUrl: 'sig-$id',
    consentMandatory: true,
    createdAt: createdAt,
  );
}

void main() {
  test('1년 안 동의서 껍질 12건은 최신 1건만 남긴다', () {
    final now = DateTime(2026, 9, 23);
    final charts = [
      for (var i = 0; i < 12; i++)
        _shell(
          id: 'shell-$i',
          visitNumber: i + 1,
          createdAt: now.subtract(Duration(days: i)),
        ),
    ];

    final plan = ChartRowCollapse.plan(charts);
    expect(plan.dropIds, hasLength(11));
    expect(plan.dropIds.contains('shell-0'), isFalse);
    expect(
      charts.where((chart) => !plan.dropIds.contains(chart.id)).single.id,
      'shell-0',
    );
  });

  test('1년을 넘긴 동의서 껍질은 그 해의 기록으로 남긴다', () {
    final plan = ChartRowCollapse.plan([
      _shell(
        id: 'new',
        visitNumber: 2,
        createdAt: DateTime(2026, 9, 23),
      ),
      _shell(
        id: 'old',
        visitNumber: 1,
        createdAt: DateTime(2025, 1, 1),
      ),
    ]);
    expect(plan.dropIds, isEmpty);
  });

  test('같은 회차의 시술 차트와 동의 껍질은 시술 차트로 합친다', () {
    final visit = CustomerChart(
      id: 'visit',
      shopId: 'shop',
      customerId: 'collapse-c',
      visitNumber: 3,
      careName: '수분케어',
      treatmentSummary: '수분 집중',
      beforeImageUrl: 'https://example.com/before.webp',
      createdAt: DateTime(2026, 9, 20),
    );
    final shell = _shell(
      id: 'shell',
      visitNumber: 3,
      createdAt: DateTime(2026, 9, 23),
    );

    final plan = ChartRowCollapse.plan([visit, shell]);
    expect(plan.dropIds, ['shell']);
    expect(plan.repoint['shell'], 'visit');
    expect(plan.merged.single.id, 'visit');
    expect(plan.merged.single.signatureUrl, 'sig-shell');
    expect(
      plan.merged.single.beforeImageUrl,
      'https://example.com/before.webp',
    );
    expect(plan.merged.single.treatmentSummary, '수분 집중');
  });

  test('공개된 후기가 달린 동의 껍질은 지우지 않는다', () {
    final plan = ChartRowCollapse.plan(
      [
        _shell(
          id: 'keep',
          visitNumber: 1,
          createdAt: DateTime(2026, 9, 23),
        ),
        _shell(
          id: 'published',
          visitNumber: 2,
          createdAt: DateTime(2026, 9, 1),
        ),
      ],
      protectedIds: {'published'},
    );
    expect(plan.dropIds.contains('published'), isFalse);
    expect(plan.dropIds, isEmpty);
  });

  test('메모리 저장소에서 동의 껍질 12건이 1건이 된다', () async {
    final store = SoriStore();
    final now = DateTime(2026, 9, 23);
    for (var i = 0; i < 12; i++) {
      store.charts.add(
        _shell(
          id: 'shell-$i',
          visitNumber: 50 + i,
          createdAt: now.subtract(Duration(days: i)),
        ),
      );
    }

    await store.collapseDuplicateChartRows();

    final left = store.charts.where((chart) => chart.id.startsWith('shell-'));
    expect(left, hasLength(1));
    expect(left.single.id, 'shell-0');
  });
}
