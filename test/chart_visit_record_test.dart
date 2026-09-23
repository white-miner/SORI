import 'package:flutter_test/flutter_test.dart';
import 'package:sori/features/chart_visit/chart_visit_live.dart';
import 'package:sori/features/chart_visit/chart_visit_mock.dart';
import 'package:sori/services/sori_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('chart visit draft saves and reopens without visit_checked', () async {
    final store = SoriStore();
    final customer = store.customers.first;
    final gate = ChartVisitLiveGateway(store: store, customer: customer);

    final session = await gate.startFresh();
    expect(session.concerns, isEmpty);
    expect(session.scores['hydration'], 0);

    session.concerns.addAll(['홍조', '건조']);
    session.since = '1~3개월';
    session.discomfort = 4;
    session.desiredChange = '붉은기가 덜 보였으면 좋겠어요';
    session.scores['redness'] = 4;
    session.scores['hydration'] = 2;
    session.summaryConcerns = '볼 홍조';
    session.consultApplied = true;
    session.goals.add('진정');
    session.steps.first.memo = '약하게';
    session.changes.add(ScoreChange(axis: '홍조', from: 4, to: 2));
    session.aftercare.add('자외선 차단');
    session.homeAm = '진정 크림';
    session.homePm = '보습';
    session.nextTiming = '2주';
    session.nextNote = '장벽';
    await gate.saveDraft(session);

    final saved = store.findChartById(session.id);
    expect(saved, isNotNull);
    expect(saved!.visitChecked, isFalse);
    expect(saved.visitRecord.isDraft, isTrue);
    expect(saved.visitRecord.concerns, ['홍조', '건조']);
    expect(saved.visitRecord.duration, '1~3개월');
    expect(saved.visitRecord.discomfortScore, 4);
    expect(saved.visitRecord.scores['redness'], 4);
    expect(saved.visitRecord.scores['hydration'], 2);
    expect(saved.visitRecord.consultApplied, isTrue);
    expect(saved.visitRecord.consultApproved['main_concerns'], '볼 홍조');
    expect(saved.visitRecord.careGoals, ['진정']);
    expect(saved.visitRecord.treatmentSteps.first['memo'], '약하게');
    expect(saved.visitRecord.treatmentSteps.first['sort'], 1);
    expect(saved.visitRecord.homeAm, '진정 크림');
    expect(saved.visitRecord.changeLine, '홍조 4 → 2');
    expect(saved.visitRecord.nextCareNote, '장벽');
    expect(saved.visitRecord.nextCareTiming, '2주');

    final reopened = ChartVisitSession.fromRecord(
      id: saved.id,
      startedAt: saved.visitRecord.visitDate ?? session.startedAt,
      record: saved.visitRecord,
    );
    expect(reopened.concerns, ['홍조', '건조']);
    expect(reopened.consultApplied, isTrue);
    expect(reopened.scores['hydration'], 2);
    expect(reopened.goals, ['진정']);
    expect(reopened.steps.first.memo, '약하게');

    final second = await gate.startFresh();
    expect(second.id, session.id);
    expect(second.concerns, ['홍조', '건조']);

    await gate.complete(session);
    final done = store.findChartById(session.id)!;
    expect(done.visitRecord.flowStatus, 'completed');
    expect(done.visitChecked, isFalse);

    final history = store
        .chartsForCustomer(customer.id)
        .where((chart) => !chart.visitRecord.isDraft)
        .toList();
    expect(history.first.id, session.id);
    expect(history.first.visitRecord.goalLine, '진정');
    expect(history.first.visitRecord.concernLine, '홍조 · 건조');
  });
}
