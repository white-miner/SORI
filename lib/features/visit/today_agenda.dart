import '../../models/customer_chart.dart';
import '../../models/home_care_prescriptions.dart';
import '../../services/sori_store.dart';
import '../../visit_kernel/models/care_schedule_entry.dart';
import '../../visit_kernel/models/visit_session.dart';
import '../operation/clinical_assistant_store.dart';
import '../operation/models/clinical_environment_brief.dart';
import '../operation/models/clinical_trend_snapshot.dart';
import '../operation/models/consultation_deep_mode.dart';
import '../operation/models/sos_signal.dart';
import '../operation/models/visit_biometrics.dart';
import '../operation/sos_signal_parser.dart';
import 'consultation_track.dart';

/// PO Sprint 3.3 — 오늘의 일정 SSOT (care_schedule + 미완료 visit_sessions 병합).
class TodayAgendaItem {
  const TodayAgendaItem({
    required this.dedupKey,
    required this.sortAt,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.schedule,
    this.session,
    required this.track,
    this.isNext = false,
    this.sosSignal = SosSignal.none,
  });

  final String dedupKey;
  final DateTime sortAt;
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final CareScheduleEntry? schedule;
  final VisitSession? session;
  final ConsultationTrack track;
  final bool isNext;
  final SosSignal sosSignal;

  bool get hasActiveSession => session != null && session!.isActive;

  bool get isReturning => track == ConsultationTrack.returning;

  String get timeLabel {
    final h = sortAt.hour.toString().padLeft(2, '0');
    final m = sortAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class TodayAgendaSnapshot {
  const TodayAgendaSnapshot({
    required this.day,
    required this.activeSessions,
    required this.items,
    required this.scheduledCount,
    required this.inProgressCount,
  });

  final DateTime day;
  final List<VisitSession> activeSessions;
  final List<TodayAgendaItem> items;
  final int scheduledCount;
  final int inProgressCount;
}

String agendaDedupKey({
  String? customerId,
  required String customerName,
  String? customerPhone,
}) {
  final cid = customerId?.trim() ?? '';
  if (cid.isNotEmpty) return 'cid:$cid';
  final phone = customerPhone?.trim() ?? '';
  if (phone.isNotEmpty) return 'phone:$phone';
  return 'name:${customerName.trim().toLowerCase()}';
}

ConsultationTrack resolveAgendaTrack(
  SoriStore store, {
  required String customerId,
  String? chartDraftId,
}) {
  final hasPrior = store
      .chartsForCustomer(customerId)
      .any((c) => c.id != chartDraftId);
  return hasPrior ? ConsultationTrack.returning : ConsultationTrack.newCustomer;
}

/// care_schedule(당일 scheduled) + visit_sessions(당일 미완료) 시간순 병합 · customer_id 기준 dedupe.
TodayAgendaSnapshot buildTodayAgenda({
  required SoriStore store,
  required DateTime now,
  required List<CareScheduleEntry> schedules,
  required List<VisitSession> sessions,
  SosSignalParser? sosParser,
}) {
  final parser = sosParser ?? SosSignalParser(mergeSosRules());
  final day = DateTime(now.year, now.month, now.day);
  final merged = <String, _AgendaMerge>{};

  for (final entry in schedules) {
    if (!entry.isSameDay(day)) continue;
    if (entry.status != CareScheduleStatus.scheduled) continue;

    final cid = entry.customerId?.trim() ?? '';
    final key = agendaDedupKey(
      customerId: entry.customerId,
      customerName: entry.customerName,
      customerPhone: entry.customerPhone,
    );
    merged.putIfAbsent(key, () => _AgendaMerge(key: key)).applySchedule(entry);
    if (cid.isNotEmpty) {
      merged[key]!.customerId = cid;
    }
  }

  for (final session in sessions) {
    if (!session.isSameDay(day)) continue;
    if (!session.isActive) continue;

    final key = agendaDedupKey(
      customerId: session.customerId,
      customerName: session.customerName,
    );
    merged.putIfAbsent(key, () => _AgendaMerge(key: key)).applySession(session);
  }

  final items = <TodayAgendaItem>[];
  for (final m in merged.values) {
    final sortAt = m.schedule?.scheduledAt ?? m.session?.startedAt ?? now;
    final customerId = m.customerId ??
        m.session?.customerId ??
        m.schedule?.customerId?.trim() ??
        '';
    final customerName =
        m.session?.customerName ?? m.schedule?.customerName ?? '고객';
    final track = customerId.isEmpty
        ? ConsultationTrack.newCustomer
        : resolveAgendaTrack(
            store,
            customerId: customerId,
            chartDraftId: m.session?.chartDraftId,
          );

    final customer = customerId.isEmpty ? null : store.findCustomer(customerId);
    CustomerChart? prior;
    if (customerId.isNotEmpty) {
      final charts = store.chartsForCustomer(customerId)
        ..sort((a, b) => b.visitNumber.compareTo(a.visitNumber));
      final draftId = m.session?.chartDraftId;
      for (final c in charts) {
        if (c.id == draftId) continue;
        prior = c;
        break;
      }
    }
    final sos = parser.scan(
      schedule: m.schedule,
      customer: customer,
      priorChart: prior,
    );

    items.add(
      TodayAgendaItem(
        dedupKey: m.key,
        sortAt: sortAt,
        customerId: customerId,
        customerName: customerName,
        customerPhone: m.schedule?.customerPhone,
        schedule: m.schedule,
        session: m.session,
        track: track,
        sosSignal: sos,
      ),
    );
  }

  items.sort((a, b) {
    final byTime = a.sortAt.compareTo(b.sortAt);
    if (byTime != 0) return byTime;
    return a.customerName.compareTo(b.customerName);
  });

  final nextIndex = _resolveNextIndex(items, now);
  if (nextIndex >= 0) {
    final next = items[nextIndex];
    items[nextIndex] = TodayAgendaItem(
      dedupKey: next.dedupKey,
      sortAt: next.sortAt,
      customerId: next.customerId,
      customerName: next.customerName,
      customerPhone: next.customerPhone,
      schedule: next.schedule,
      session: next.session,
      track: next.track,
      isNext: true,
      sosSignal: next.sosSignal,
    );
  }

  final activeSessions = sessions
      .where((s) => s.isSameDay(day) && s.isActive)
      .toList()
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  final scheduledCount =
      schedules.where((e) => e.isSameDay(day) && e.status == CareScheduleStatus.scheduled).length;

  return TodayAgendaSnapshot(
    day: day,
    activeSessions: activeSessions,
    items: items,
    scheduledCount: scheduledCount,
    inProgressCount: activeSessions.length,
  );
}

int _resolveNextIndex(List<TodayAgendaItem> items, DateTime now) {
  if (items.isEmpty) return -1;

  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    if (item.hasActiveSession) continue;
    if (!item.sortAt.isBefore(now.subtract(const Duration(minutes: 5)))) {
      return i;
    }
  }

  for (var i = 0; i < items.length; i++) {
    if (!items[i].hasActiveSession) return i;
  }
  return -1;
}

/// Briefing sheet에 필요한 읽기 전용 컨텍스트.
class ConsultationBriefing {
  const ConsultationBriefing({
    required this.item,
    required this.track,
    this.priorChart,
    this.visitNumber,
    this.lastVisitDate,
    this.todayPlanLabel = '',
    this.homeCareLabels = const [],
    this.sosSignal = SosSignal.none,
    this.biometrics = const VisitBiometrics(),
    this.deepMode = ConsultationDeepMode.fullDesign,
    this.environmentBrief = ClinicalEnvironmentBrief.standard,
    this.trendLead,
  });

  final TodayAgendaItem item;
  final ConsultationTrack track;
  final CustomerChart? priorChart;
  final int? visitNumber;
  final DateTime? lastVisitDate;
  final String todayPlanLabel;
  final List<String> homeCareLabels;
  final SosSignal sosSignal;
  final VisitBiometrics biometrics;
  final ConsultationDeepMode deepMode;
  final ClinicalEnvironmentBrief environmentBrief;
  final ClinicalTrendItem? trendLead;

  List<String> get concernChips => priorChart?.careTags ?? const [];

  String get priorTreatmentLabel {
    final chart = priorChart;
    if (chart == null) return '';
    final summary = chart.treatmentSummary.trim();
    if (summary.isNotEmpty) return summary;
    return chart.careName.trim();
  }
}

ConsultationBriefing buildConsultationBriefing(
  SoriStore store,
  TodayAgendaItem item, {
  VisitBiometrics? biometricsOverride,
}) {
  final cid = item.customerId.trim();
  CustomerChart? prior;
  if (cid.isNotEmpty) {
    final charts = store.chartsForCustomer(cid)
      ..sort((a, b) => b.visitNumber.compareTo(a.visitNumber));
    final draftId = item.session?.chartDraftId;
    for (final c in charts) {
      if (c.id == draftId) continue;
      prior = c;
      break;
    }
  }

  final todayDraft = item.session != null
      ? store.chartForVisitSession(item.session!)
      : null;
  final visitNo = todayDraft?.visitNumber ?? prior?.visitNumber;
  final biometrics = biometricsOverride ??
      todayDraft?.visitBiometrics ??
      const VisitBiometrics();
  final climate = ClinicalAssistantStore.instance.current;
  final trendLead = ClinicalAssistantStore.instance.trends?.briefingLead;
  final deepMode = resolveDeepMode(
    track: item.track,
    sos: item.sosSignal,
    biometrics: biometrics,
    ssiBand: climate?.ssi.band,
  );

  final scheduleLabel = item.schedule?.careLabel.trim() ?? '';
  final homeTags = prior?.homeCarePrescriptions ?? const <String>[];
  final homeLabels = homeTags
      .map((t) => HomecareDictionary.chipLabelOf(t) ?? t)
      .where((e) => e.trim().isNotEmpty)
      .toList(growable: false);

  var planLabel = scheduleLabel;
  if (planLabel.isEmpty && homeLabels.isNotEmpty) {
    planLabel = homeLabels.first;
  }

  DateTime? lastVisit;
  if (prior?.createdAt != null) {
    lastVisit = prior!.createdAt;
  } else if (cid.isNotEmpty) {
    final customer = store.findCustomer(cid);
    if (customer != null && customer.lastTreatmentDate.year > 1970) {
      lastVisit = customer.lastTreatmentDate;
    }
  }

  return ConsultationBriefing(
    item: item,
    track: item.track,
    priorChart: prior,
    visitNumber: visitNo,
    lastVisitDate: lastVisit,
    todayPlanLabel: planLabel,
    homeCareLabels: homeLabels,
    sosSignal: item.sosSignal,
    biometrics: biometrics,
    deepMode: deepMode,
    environmentBrief: climate?.brief ?? ClinicalEnvironmentBrief.standard,
    trendLead: trendLead,
  );
}

class _AgendaMerge {
  _AgendaMerge({required this.key});

  final String key;
  CareScheduleEntry? schedule;
  VisitSession? session;
  String? customerId;

  void applySchedule(CareScheduleEntry entry) {
    schedule = entry;
    final cid = entry.customerId?.trim() ?? '';
    if (cid.isNotEmpty) customerId = cid;
  }

  void applySession(VisitSession s) {
    session = s;
    customerId = s.customerId;
  }
}