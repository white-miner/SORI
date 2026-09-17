import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/visit/my_today_task_queue.dart';
import 'package:sori/models/customer_chart.dart';

CustomerChart _chart({
  required String id,
  required String customerId,
  bool visitChecked = false,
  String summary = '',
  String insight = '',
  DateTime? checkedAt,
}) {
  return CustomerChart(
    id: id,
    shopId: 'shop',
    customerId: customerId,
    visitNumber: 1,
    visitChecked: visitChecked,
    visitCheckedAt: checkedAt,
    treatmentSummary: summary,
    directorInsight: insight,
  );
}

void main() {
  final now = DateTime(2026, 9, 11, 15);

  test('incomplete = visitChecked && !hasSummary', () {
    expect(
      MyTodayTaskQueue.isIncompleteRecord(
        _chart(id: '1', customerId: 'c', visitChecked: true),
      ),
      isTrue,
    );
    expect(
      MyTodayTaskQueue.isIncompleteRecord(
        _chart(
          id: '2',
          customerId: 'c',
          visitChecked: true,
          summary: '케어 완료',
        ),
      ),
      isFalse,
    );
    expect(
      MyTodayTaskQueue.isIncompleteRecord(
        _chart(id: '3', customerId: 'c', visitChecked: false),
      ),
      isFalse,
    );
    expect(
      MyTodayTaskQueue.hasSummary(
        _chart(id: '4', customerId: 'c', insight: '인사이트'),
      ),
      isTrue,
    );
  });

  test('build max 3 · newest visitCheckedAt first · concrete copy', () {
    final charts = [
      _chart(
        id: 'old',
        customerId: 'a',
        visitChecked: true,
        checkedAt: DateTime(2026, 9, 8),
      ),
      _chart(
        id: 'mid',
        customerId: 'b',
        visitChecked: true,
        checkedAt: DateTime(2026, 9, 10),
      ),
      _chart(
        id: 'new',
        customerId: 'c',
        visitChecked: true,
        checkedAt: DateTime(2026, 9, 11),
      ),
      _chart(
        id: 'extra',
        customerId: 'd',
        visitChecked: true,
        checkedAt: DateTime(2026, 9, 7),
      ),
      _chart(
        id: 'done',
        customerId: 'e',
        visitChecked: true,
        summary: '요약',
        checkedAt: DateTime(2026, 9, 11),
      ),
    ];
    final tasks = MyTodayTaskQueue.buildIncompleteRecordTasks(
      charts: charts,
      customerNameOf: (id) => ({
            'a': '김',
            'b': '이',
            'c': '박',
            'd': '최',
          }[id] ??
          ''),
      now: now,
    );
    expect(tasks.length, 3);
    expect(tasks.map((t) => t.chartId).toList(), ['new', 'mid', 'old']);
    expect(tasks.first.subtitle, '시술 요약이 아직 없어요');
    expect(tasks.first.title.contains('오늘 방문'), isTrue);
  });

  test('does not invent payment or no_show tasks', () {
    final tasks = MyTodayTaskQueue.buildIncompleteRecordTasks(
      charts: [
        _chart(id: '1', customerId: 'a', visitChecked: false),
      ],
      customerNameOf: (_) => '테스트',
    );
    expect(tasks, isEmpty);
  });
}
