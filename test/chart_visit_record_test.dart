import 'package:flutter_test/flutter_test.dart';
import 'package:sori/features/chart_visit/chart_visit_live.dart';
import 'package:sori/features/chart_visit/chart_visit_mock.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/models/chart_visit_record.dart';
import 'package:sori/models/customer.dart';

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
    session.steps.add(CareStepDraft(title: '등 관리', memo: '약하게'));
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

  test('empty saved steps stay empty in wizard and workspace', () async {
    final store = SoriStore();
    final customer = store.customers.first;
    final gate = ChartVisitLiveGateway(store: store, customer: customer);

    final session = await gate.startFresh(forceNew: true);
    expect(session.steps, isEmpty);
    session.steps.clear();
    await gate.saveDraft(session);

    final saved = store.findChartById(session.id)!;
    expect(saved.visitRecord.treatmentSteps, isEmpty);
    final draft = ChartVisitDraftRef(chartId: saved.id, record: saved.visitRecord);

    // 위저드도 사용자가 기록하지 않은 관리를 생성하지 않는다.
    final wizard = await gate.resumeLatest(draft);
    expect(wizard.steps, isEmpty);
    final reopened = ChartVisitSession.fromRecord(
      id: saved.id,
      startedAt: session.startedAt,
      record: saved.visitRecord,
    );
    expect(reopened.steps, isEmpty);

    // 작성 데스크: 저장된 빈 목록을 그대로 둔다.
    final desk = await gate.resumeLatest(draft, refillDefaultSteps: false);
    expect(desk.steps, isEmpty);
    expect(
      ChartVisitSession.fromRecord(
        id: saved.id,
        startedAt: session.startedAt,
        record: saved.visitRecord,
        refillDefaultSteps: false,
      ).steps,
      isEmpty,
    );
  });

  test('unknown safety remains unknown while explicit none survives round trip', () {
    final customer = Customer(id: 'new', name: '검수', phone: '',
        lastTreatmentDate: DateTime(2026, 10, 1), treatmentType: '');
    final safety = safetyFromCustomer(customer);
    expect(safety.allergy, isEmpty);
    expect(safety.pregnancy, isEmpty);
    final session = ChartVisitSession.fresh(id: 'draft',
        startedAt: DateTime(2026, 10, 1), safety: safety);
    final reopened = ChartVisitSession.fromRecord(id: session.id,
        startedAt: session.startedAt,
        record: ChartVisitRecord.fromMap(session.toRecord().toPatch()));
    expect(reopened.safety.medication, isEmpty);
    expect(reopened.steps, isEmpty);
    expect(reopened.scores.values.every((v) => v == 0), isTrue);
    expect(reopened.beforeCaptured, isEmpty);
    expect(reopened.afterCaptured, isEmpty);
    expect(reopened.summaryJudgement, isEmpty);
    session.safety = safety.copyWith(allergy: '없음', pregnancy: '해당 없음');
    final confirmed = safetyFromRecord(ChartVisitRecord.fromMap(session.toRecord().toPatch()));
    expect(confirmed.allergy, '없음');
    expect(confirmed.pregnancy, '해당 없음');
    expect(confirmed.medication, isEmpty);
  });

  test('reaction unknown none and recorded remain distinct through DB patch', () {
    for (final record in [
      const ChartVisitRecord(),
      const ChartVisitRecord(reactionNone: true),
      const ChartVisitRecord(reactionTypes: ['열감']),
    ]) {
      final restored = ChartVisitRecord.fromMap(record.toPatch());
      expect(restored.reactionNone, record.reactionNone);
      expect(restored.reactionTypes, record.reactionTypes);
    }
    expect(ChartVisitRecord.fromMap({}).reactionNone, isFalse);
    expect(ChartVisitRecord.empty.toPatch()['care_reactions']['has_reaction'], isNull);
    // 기존 명시적 false는 보존한다. 자동 기본값인지 사후 추정하지 않는다.
    expect(ChartVisitRecord.fromMap({'care_reactions': {'has_reaction': false}}).reactionNone, isTrue);
  });

  test('resuming a blank draft preserves its original safety snapshot', () async {
    final store = SoriStore();
    final original = store.customers.first;
    final draft = await store.createChartVisitDraft(customerId: original.id,
        record: const ChartVisitRecord(flowStatus: 'draft', safety: {'medication': '없음'}));
    final changedCustomer = Customer(id: original.id, name: original.name,
        phone: original.phone, lastTreatmentDate: original.lastTreatmentDate,
        treatmentType: original.treatmentType, medicationHistory: '변경된 복용 정보');
    final gate = ChartVisitLiveGateway(store: store, customer: changedCustomer);
    final session = await gate.startFresh();
    expect(session.id, draft.id);
    expect(session.safety.medication, '없음');
    expect(session.steps, isEmpty);
  });
}
