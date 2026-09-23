import '../../models/chart_visit_record.dart';
import '../../models/customer.dart';
import '../../models/customer_chart.dart';
import '../../services/sori_store.dart';
import 'chart_visit_mock.dart';

/// 실제 고객·방문으로 CHART 미리보기 스토어를 채운다.
void bindChartVisitRoute(SoriStore store, String customerId) {
  final preview = ChartVisitPreviewStore.instance;
  final id = customerId.trim();
  if (id.isEmpty) {
    if (preview.live) preview.detachIfLive();
    return;
  }
  if (preview.live && preview.liveCustomerId == id) return;

  final customer = store.findCustomer(id);
  if (customer == null) {
    preview.failLive('고객을 찾지 못했습니다');
    return;
  }

  final charts = store.chartsForCustomer(id);
  final drafts = charts
      .where((chart) => chart.visitRecord.isDraft)
      .map(
        (chart) => ChartVisitDraftRef(
          chartId: chart.id,
          record: chart.visitRecord,
        ),
      )
      .toList();
  final history = [
    for (final chart in charts)
      if (!chart.visitRecord.isDraft) pastVisitFromChart(chart),
  ];
  preview.bindLive(
    nextCustomer: chartVisitCustomerFrom(customer, charts),
    nextHistory: history,
    nextDrafts: drafts,
    nextGateway: ChartVisitLiveGateway(store: store, customer: customer),
    customerId: id,
  );
}

ChartVisitCustomer chartVisitCustomerFrom(
  Customer customer,
  List<CustomerChart> charts,
) {
  final finished = charts.where((chart) => !chart.visitRecord.isDraft).toList();
  DateTime? first;
  DateTime? last;
  for (final chart in finished) {
    final day = chart.visitRecord.visitDate ?? chart.createdAt ?? chart.visitCheckedAt;
    if (day == null) continue;
    if (first == null || day.isBefore(first)) first = day;
    if (last == null || day.isAfter(last)) last = day;
  }
  final now = DateTime.now();
  return ChartVisitCustomer(
    name: customer.name,
    age: customer.koreanAge ?? 0,
    genderLabel: customer.gender?.label ?? '',
    phone: customer.phone,
    firstVisit: first ?? now,
    lastVisit: last ?? now,
    visitCount: finished.length,
    skinTrait: customer.skinTrait,
    safety: safetyFromCustomer(customer),
  );
}

SafetySnapshot safetyFromCustomer(Customer customer) {
  String orNone(String value, [String empty = '없음']) {
    final text = value.trim();
    return text.isEmpty ? empty : text;
  }

  return SafetySnapshot(
    allergy: orNone(customer.allergyNotes),
    medication: orNone(customer.medicationHistory),
    condition: orNone(customer.medicalCondition),
    pregnancy: orNone(customer.pregnancyStatus, '해당 없음'),
    recentProcedure: orNone(customer.recentProcedure),
    activeProduct: orNone(customer.activeProduct),
  );
}

SafetySnapshot safetyFromRecord(ChartVisitRecord record) {
  String pick(String key, [String empty = '없음']) {
    final text = record.safety[key]?.trim() ?? '';
    return text.isEmpty ? empty : text;
  }

  return SafetySnapshot(
    allergy: pick('allergy'),
    medication: pick('medication'),
    condition: pick('condition'),
    pregnancy: pick('pregnancy', '해당 없음'),
    recentProcedure: pick('recent_procedure'),
    activeProduct: pick('active_product'),
  );
}

PastVisit pastVisitFromChart(CustomerChart chart) {
  final record = chart.visitRecord;
  final title = record.goalLine.isNotEmpty
      ? record.goalLine
      : (chart.careName.trim().isEmpty ? '방문' : chart.careName.trim());
  return PastVisit(
    id: chart.id,
    date: record.visitDate ?? chart.createdAt ?? chart.visitCheckedAt ?? DateTime.now(),
    title: title,
    note: record.concernLine.isNotEmpty ? record.concernLine : record.desiredChange,
    changeLine: record.changeLine,
    hasPhotos: (chart.beforeImageUrl ?? '').trim().isNotEmpty ||
        (chart.afterImageUrl ?? '').trim().isNotEmpty,
    safety: record.safety.isEmpty
        ? const SafetySnapshot()
        : safetyFromRecord(record),
  );
}

class ChartVisitLiveGateway implements ChartVisitGateway {
  ChartVisitLiveGateway({
    required this.store,
    required this.customer,
  });

  final SoriStore store;
  final Customer customer;
  String? chartId;

  @override
  Future<ChartVisitSession> startFresh() async {
    final safety = safetyFromCustomer(customer);
    final record = ChartVisitRecord(
      flowStatus: 'draft',
      visitDate: DateTime.now(),
      safety: {
        'allergy': safety.allergy,
        'medication': safety.medication,
        'condition': safety.condition,
        'pregnancy': safety.pregnancy,
        'recent_procedure': safety.recentProcedure,
        'active_product': safety.activeProduct,
        if (customer.skinTrait.trim().isNotEmpty) 'skin_trait': customer.skinTrait.trim(),
      },
    );
    final chart = await store.createChartVisitDraft(
      customerId: customer.id,
      record: record,
    );
    chartId = chart.id;
    final session = ChartVisitSession.fresh(
      id: chart.id,
      startedAt: chart.visitRecord.visitDate ?? DateTime.now(),
      safety: safety,
    );
    session.skinTraitHint = customer.skinTrait.trim();
    return session;
  }

  @override
  Future<ChartVisitSession> resumeLatest(ChartVisitDraftRef draft) async {
    chartId = draft.chartId;
    final session = ChartVisitSession.fromRecord(
      id: draft.chartId,
      startedAt: draft.record.visitDate ?? DateTime.now(),
      record: draft.record,
    );
    session.skinTraitHint =
        draft.record.safety['skin_trait'] ?? customer.skinTrait.trim();
    return session;
  }

  @override
  Future<void> saveDraft(ChartVisitSession session) async {
    final id = session.id;
    chartId = id;
    final record = session.toRecord(flowStatus: 'draft');
    await store.saveChartVisitDraft(chartId: id, record: record);
    if (!session.safetyDirty) return;
    await store.patchChartVisitCustomerSafety(
      customerId: customer.id,
      patch: record.customerSafetyPatch(),
    );
    session.safetyDirty = false;
  }

  @override
  Future<void> complete(ChartVisitSession session) async {
    final id = session.id;
    chartId = id;
    if (session.safetyDirty) {
      await store.patchChartVisitCustomerSafety(
        customerId: customer.id,
        patch: session.toRecord().customerSafetyPatch(),
      );
      session.safetyDirty = false;
    }
    await store.saveChartVisitDraft(
      chartId: id,
      record: session.toRecord(flowStatus: 'completed'),
    );
  }
}
