import 'package:flutter/foundation.dart';

import '../../models/chart_visit_record.dart';

/// UI 검증용 샘플. Supabase·`customer_charts` 와 연결하지 않는다.
///
/// Customer = 현재 안전 정보.
/// Visit session = 그 방문에 복사해 둔 스냅샷. 과거 방문 행은 수정하지 않는다.

class SafetySnapshot {
  const SafetySnapshot({
    this.allergy = '없음',
    this.medication = '없음',
    this.condition = '없음',
    this.pregnancy = '해당 없음',
    this.recentProcedure = '없음',
    this.activeProduct = '없음',
  });

  final String allergy;
  final String medication;
  final String condition;
  final String pregnancy;
  final String recentProcedure;
  final String activeProduct;

  SafetySnapshot copyWith({
    String? allergy,
    String? medication,
    String? condition,
    String? pregnancy,
    String? recentProcedure,
    String? activeProduct,
  }) {
    return SafetySnapshot(
      allergy: allergy ?? this.allergy,
      medication: medication ?? this.medication,
      condition: condition ?? this.condition,
      pregnancy: pregnancy ?? this.pregnancy,
      recentProcedure: recentProcedure ?? this.recentProcedure,
      activeProduct: activeProduct ?? this.activeProduct,
    );
  }
}

class PastVisit {
  const PastVisit({
    required this.id,
    required this.date,
    required this.title,
    required this.safety,
    this.note = '',
    this.changeLine = '',
    this.hasPhotos = false,
    this.first = false,
  });

  final String id;
  final DateTime date;
  final String title;
  final String note;
  final String changeLine;
  final bool hasPhotos;
  final bool first;
  final SafetySnapshot safety;
}

class CareStepDraft {
  CareStepDraft({
    required this.title,
    this.product = '',
    this.device = '',
    this.intensity = '',
    this.minutes = '',
    this.area = '',
    this.memo = '',
    this.expanded = false,
    this.detailsOpen = false,
  });

  String title;
  String product;
  String device;
  String intensity;
  String minutes;
  String area;
  String memo;
  bool expanded;
  bool detailsOpen;
}

class ScoreChange {
  ScoreChange({required this.axis, required this.from, required this.to});

  String axis;
  int from;
  int to;
}

enum ConsultPhase { idle, recording, paused, summarized }

/// 피부 축. 값은 1–5 숫자만. 0은 아직 안 누른 상태.
const List<(String id, String label)> kSkinAxes = [
  ('hydration', '수분'),
  ('oil', '유분'),
  ('sensitivity', '민감'),
  ('redness', '홍조'),
  ('keratin', '각질'),
  ('pores', '모공'),
  ('pigmentation', '색소'),
  ('elasticity', '탄력'),
  ('acne', '트러블'),
];

const List<String> kConcernChoices = [
  '건조',
  '유분',
  '민감',
  '홍조',
  '여드름',
  '모공',
  '블랙헤드',
  '색소',
  '잡티',
  '각질',
  '피부결',
  '탄력',
  '주름',
  '흉터',
  '기타',
];

const List<String> kSinceChoices = [
  '최근',
  '1~3개월',
  '3~6개월',
  '6~12개월',
  '1년 이상',
];

const List<String> kCareGoals = [
  '진정',
  '수분',
  '장벽',
  '피지',
  '각질',
  '미백',
  '탄력',
  '트러블',
];

const List<String> kAftercare = [
  '강한 세안 피하기',
  '각질제거 피하기',
  '사우나 / 찜질방 피하기',
  '자외선 차단',
  '충분한 보습',
  '기능성 제품 일시 중단',
];

const List<String> kNextTimings = ['1주', '2주', '3주', '4주', '직접 설정'];

class ChartVisitSession {
  ChartVisitSession({
    required this.id,
    required this.startedAt,
    required this.safety,
  });

  final String id;
  final DateTime startedAt;
  SafetySnapshot safety;

  final List<String> concerns = [];
  String since = '최근';
  int discomfort = 4;
  String desiredChange = '화장했을 때 붉은기가 덜 보였으면 좋겠어요.';

  final Map<String, int> scores = {
    'hydration': 2,
    'oil': 3,
    'sensitivity': 4,
    'redness': 4,
    'keratin': 3,
    'pores': 2,
    'pigmentation': 3,
    'elasticity': 2,
    'acne': 1,
  };

  final List<String> beforeAngles = ['정면', '좌측', '우측'];
  final Set<String> beforeCaptured = {'정면'};

  ConsultPhase consult = ConsultPhase.idle;
  int consultSeconds = 0;
  bool consultApplied = false;
  String summaryConcerns = '최근 볼 홍조 증가\n세안 후 당김\n오후 피부 건조';
  String summaryLife = '레티놀 주 3회 사용\n자외선 차단제 사용\n각질제거 주 2회';
  String summaryJudgement = '피부 장벽 저하 가능성\n볼 부위 민감도 높음';
  String summaryWish = '홍조 완화\n세안 후 당김 감소';

  final List<String> goals = ['진정', '수분', '장벽'];
  final List<CareStepDraft> steps = [
    CareStepDraft(title: '클렌징'),
    CareStepDraft(title: '효소 각질관리'),
    CareStepDraft(title: '진정 앰플'),
    CareStepDraft(title: '초음파'),
    CareStepDraft(title: '진정팩'),
  ];
  bool reactionNone = true;
  final Set<String> reactions = {};

  final List<String> afterAngles = ['정면', '좌측', '우측'];
  final Set<String> afterCaptured = {'정면'};
  final List<ScoreChange> changes = [
    ScoreChange(axis: '홍조', from: 4, to: 2),
    ScoreChange(axis: '수분', from: 2, to: 4),
  ];
  final Set<String> aftercare = {
    '강한 세안 피하기',
    '자외선 차단',
    '충분한 보습',
  };
  String homeAm = '순한 세안 · 진정 크림 · 자외선 차단';
  String homePm = '순한 세안 · 보습. 레티놀은 오늘 쉬기';
  String nextTiming = '2주';
  String nextNote = '장벽 / 수분 관리';
  bool committed = false;
  bool safetyDirty = false;

  ChartVisitSession.fresh({
    required this.id,
    required this.startedAt,
    required this.safety,
  }) {
    scores.updateAll((key, value) => 0);
    since = '';
    discomfort = 0;
    desiredChange = '';
    summaryConcerns = '';
    summaryLife = '';
    summaryJudgement = '';
    summaryWish = '';
    goals.clear();
    changes.clear();
    aftercare.clear();
    beforeCaptured.clear();
    afterCaptured.clear();
    homeAm = '';
    homePm = '';
    nextTiming = '';
    nextNote = '';
  }

  /// [refillDefaultSteps] 가 true(기본)면 저장된 시술 단계가 비어 있을 때 기본 5단계를 쓴다
  /// (위저드 동작). false 면 저장된 빈 목록을 그대로 지킨다(오늘 방문 작성 데스크).
  factory ChartVisitSession.fromRecord({
    required String id,
    required DateTime startedAt,
    required ChartVisitRecord record,
    bool refillDefaultSteps = true,
  }) {
    final session = ChartVisitSession.fresh(
      id: id,
      startedAt: startedAt,
      safety: SafetySnapshot(
        allergy: record.safety['allergy'] ?? '없음',
        medication: record.safety['medication'] ?? '없음',
        condition: record.safety['condition'] ?? '없음',
        pregnancy: record.safety['pregnancy'] ?? '해당 없음',
        recentProcedure: record.safety['recent_procedure'] ?? '없음',
        activeProduct: record.safety['active_product'] ?? '없음',
      ),
    );
    session.concerns.addAll(record.concerns);
    session.since = record.duration;
    session.discomfort = record.discomfortScore ?? 0;
    session.desiredChange = record.desiredChange;
    for (final entry in record.scores.entries) {
      session.scores[entry.key] = entry.value;
    }
    session.consultApplied = record.consultApplied;
    session.summaryConcerns =
        record.consultApproved['main_concerns'] ??
        record.consultGenerated['main_concerns'] ??
        '';
    session.summaryLife =
        record.consultApproved['homecare'] ??
        record.consultGenerated['homecare'] ??
        '';
    session.summaryJudgement =
        record.consultApproved['director_assessment'] ??
        record.consultGenerated['director_assessment'] ??
        '';
    session.summaryWish =
        record.consultApproved['desired_change'] ??
        record.consultGenerated['desired_change'] ??
        '';
    if (record.consultApplied || record.consultGenerated.isNotEmpty) {
      session.consult = ConsultPhase.summarized;
    }
    session.goals
      ..clear()
      ..addAll(record.careGoals);
    if (record.treatmentSteps.isNotEmpty || !refillDefaultSteps) {
      session.steps
        ..clear()
        ..addAll(record.treatmentSteps.map(_stepFromMap));
    }
    session.reactionNone = record.reactionNone;
    session.reactions.addAll(record.reactionTypes);
    session.changes.addAll([
      for (final change in record.scoreChanges)
        ScoreChange(
          axis: ChartVisitRecord.axisLabel[change.axis] ?? change.axis,
          from: change.from,
          to: change.to,
        ),
    ]);
    session.aftercare.addAll(record.aftercare);
    session.homeAm = record.homeAm;
    session.homePm = record.homePm;
    session.nextNote = record.nextCareNote;
    session.nextTiming = record.nextCareTiming;
    return session;
  }

  ChartVisitRecord toRecord({String? flowStatus}) {
    int? scoreOf(String id) {
      final n = scores[id] ?? 0;
      if (n < 1 || n > 5) return null;
      return n;
    }

    final generated = <String, String>{
      'main_concerns': summaryConcerns,
      'homecare': summaryLife,
      'director_assessment': summaryJudgement,
      'desired_change': summaryWish,
    };
    return ChartVisitRecord(
      flowStatus: flowStatus,
      visitDate: startedAt,
      scores: {
        for (final id in ChartVisitRecord.scoreColumns.keys)
          if (scoreOf(id) != null) id: scoreOf(id)!,
      },
      discomfortScore: discomfort >= 1 && discomfort <= 5 ? discomfort : null,
      concerns: List<String>.from(concerns),
      duration: since,
      desiredChange: desiredChange,
      safety: {
        'allergy': safety.allergy,
        'medication': safety.medication,
        'condition': safety.condition,
        'pregnancy': safety.pregnancy,
        'recent_procedure': safety.recentProcedure,
        'active_product': safety.activeProduct,
        if (skinTraitHint.isNotEmpty) 'skin_trait': skinTraitHint,
      },
      consultGenerated: generated,
      consultApproved: consultApplied ? generated : const {},
      consultApplied: consultApplied,
      careGoals: List<String>.from(goals),
      treatmentSteps: [
        for (var i = 0; i < steps.length; i++)
          {
            'sort': i + 1,
            'title': steps[i].title,
            'product': steps[i].product,
            'device': steps[i].device,
            'intensity': steps[i].intensity,
            'minutes': int.tryParse(steps[i].minutes.trim()),
            'area': steps[i].area,
            'memo': steps[i].memo,
          },
      ],
      reactionNone: reactionNone || reactions.isEmpty,
      reactionTypes: reactions.toList(),
      aftercare: aftercare.toList(),
      homeAm: homeAm,
      homePm: homePm,
      scoreChanges: [
        for (final change in changes)
          (
            axis: _axisId(change.axis),
            from: change.from,
            to: change.to,
          ),
      ],
      nextCareNote: nextNote,
      nextCareTiming: nextTiming,
    );
  }

  String skinTraitHint = '';

  String get concernLine => concerns.join(' · ');

  String get goalLine {
    final names = <String>[...goals];
    if (names.isEmpty) return '관리';
    return names.join(' · ');
  }
}

class ChartVisitCustomer {
  ChartVisitCustomer({
    required this.name,
    required this.age,
    required this.genderLabel,
    required this.phone,
    required this.firstVisit,
    required this.lastVisit,
    required this.visitCount,
    required this.skinTrait,
    required this.safety,
  });

  final String name;
  final int age;
  final String genderLabel;
  final String phone;
  DateTime firstVisit;
  DateTime lastVisit;
  int visitCount;
  String skinTrait;
  SafetySnapshot safety;

  List<String> get checkLines {
    final lines = <String>[];
    if (skinTrait.trim().isNotEmpty) lines.add(skinTrait.trim());
    if (safety.activeProduct.trim().isNotEmpty &&
        safety.activeProduct.trim() != '없음') {
      lines.add(safety.activeProduct.trim());
    }
    final allergy = safety.allergy.trim();
    lines.add(allergy.isEmpty || allergy == '없음' ? '알레르기 없음' : '알레르기 $allergy');
    return lines;
  }

  /// 홈 CHECK. 없음은 경고로 올리지 않는다.
  String get homeCheck {
    final parts = <String>[];
    if (skinTrait.trim().isNotEmpty) parts.add(skinTrait.trim());
    final product = safety.activeProduct.trim();
    if (product.isNotEmpty && product != '없음') parts.add(product);
    final allergy = safety.allergy.trim();
    if (allergy.isNotEmpty && allergy != '없음') parts.add('알레르기 $allergy');
    return parts.join(' · ');
  }
}

class ChartVisitDraftRef {
  const ChartVisitDraftRef({
    required this.chartId,
    required this.record,
  });

  final String chartId;
  final ChartVisitRecord record;
}

abstract class ChartVisitGateway {
  Future<ChartVisitSession> startFresh({bool forceNew = false});
  /// [refillDefaultSteps] 는 [ChartVisitSession.fromRecord] 와 같다(기본 true = 위저드 동작).
  Future<ChartVisitSession> resumeLatest(
    ChartVisitDraftRef draft, {
    bool refillDefaultSteps = true,
  });
  Future<void> saveDraft(ChartVisitSession session);
  Future<void> complete(ChartVisitSession session);
}

class ChartVisitPreviewStore extends ChangeNotifier {
  ChartVisitPreviewStore._() {
    _loadSeed();
  }

  static final ChartVisitPreviewStore instance = ChartVisitPreviewStore._();

  late ChartVisitCustomer customer;
  late List<PastVisit> history;
  ChartVisitSession? active;
  ChartVisitGateway? gateway;
  bool live = false;
  String? liveCustomerId;
  String liveNotice = '';
  final List<ChartVisitDraftRef> drafts = [];

  void _loadSeed() {
    const safety = SafetySnapshot(
      allergy: '없음',
      medication: '없음',
      condition: '없음',
      pregnancy: '해당 없음',
      recentProcedure: '없음',
      activeProduct: '레티놀 사용',
    );
    customer = ChartVisitCustomer(
      name: '김소리',
      age: 34,
      genderLabel: '여성',
      phone: '010-1234-5678',
      firstVisit: DateTime(2026, 3, 14),
      lastVisit: DateTime(2026, 9, 23),
      visitCount: 8,
      skinTrait: '민감성',
      safety: safety,
    );
    history = [
      PastVisit(
        id: 'v-0923',
        date: DateTime(2026, 9, 23),
        title: '진정 · 수분관리',
        note: '볼 홍조 감소 / 당김 개선',
        changeLine: '홍조 4 → 2 · 수분 2 → 4',
        safety: safety,
      ),
      PastVisit(
        id: 'v-0902',
        date: DateTime(2026, 9, 2),
        title: '장벽관리',
        safety: const SafetySnapshot(activeProduct: '레티놀 사용'),
      ),
      PastVisit(
        id: 'v-0812',
        date: DateTime(2026, 8, 12),
        title: '수분관리',
        safety: const SafetySnapshot(),
      ),
      PastVisit(
        id: 'v-0721',
        date: DateTime(2026, 7, 21),
        title: '첫 방문',
        first: true,
        safety: const SafetySnapshot(activeProduct: '없음'),
      ),
    ];
    active = null;
  }

  void debugResetForTest() {
    live = false;
    gateway = null;
    liveCustomerId = null;
    liveNotice = '';
    drafts.clear();
    _loadSeed();
    notifyListeners();
  }

  void detachIfLive() {
    if (!live) return;
    debugResetForTest();
  }

  void bindLive({
    required ChartVisitCustomer nextCustomer,
    required List<PastVisit> nextHistory,
    required List<ChartVisitDraftRef> nextDrafts,
    required ChartVisitGateway nextGateway,
    required String customerId,
  }) {
    if (live && liveCustomerId == customerId && active != null) {
      customer = nextCustomer;
      history = nextHistory;
      drafts
        ..clear()
        ..addAll(nextDrafts.where((draft) => draft.chartId != active!.id));
      gateway = nextGateway;
      liveNotice = '';
      notifyListeners();
      return;
    }
    live = true;
    liveCustomerId = customerId;
    customer = nextCustomer;
    history = nextHistory;
    drafts
      ..clear()
      ..addAll(nextDrafts);
    gateway = nextGateway;
    liveNotice = '';
    active = null;
    notifyListeners();
  }

  void failLive(String message) {
    live = true;
    gateway = null;
    liveCustomerId = null;
    drafts.clear();
    active = null;
    liveNotice = message;
    notifyListeners();
  }

  Future<bool> openLiveFresh({bool forceNew = false}) async {
    final gate = gateway;
    if (gate == null) return false;
    final session = await gate.startFresh(forceNew: forceNew);
    active = session;
    notifyListeners();
    return true;
  }

  Future<bool> openLiveResume() async {
    final gate = gateway;
    if (gate == null || drafts.isEmpty) return false;
    final session = await gate.resumeLatest(drafts.first);
    active = session;
    notifyListeners();
    return true;
  }

  ChartVisitSession startNewVisit() {
    final session = ChartVisitSession(
      id: 'visit-${DateTime.now().microsecondsSinceEpoch}',
      startedAt: DateTime(2026, 9, 23, 10, 2),
      safety: customer.safety.copyWith(),
    );
    active = session;
    notifyListeners();
    return session;
  }

  void updateActiveSafety(SafetySnapshot next) {
    final session = active;
    if (session == null) return;
    session.safety = next;
    session.safetyDirty = true;
    customer.safety = next;
    notifyListeners();
  }

  void touch() => notifyListeners();

  /// 완료된 세션을 히스토리 맨 앞에 추가한다. 기존 행은 그대로 둔다.
  PastVisit? commitActiveVisit() {
    final session = active;
    if (session == null || session.committed) return null;
    session.committed = true;
    final visit = PastVisit(
      id: session.id,
      date: DateTime(2026, 9, 23),
      title: session.goalLine,
      note: session.desiredChange,
      changeLine: session.changes
          .map((c) => '${c.axis} ${c.from} → ${c.to}')
          .join(' · '),
      hasPhotos: session.beforeCaptured.isNotEmpty ||
          session.afterCaptured.isNotEmpty,
      safety: session.safety.copyWith(),
    );
    history = [visit, ...history];
    customer.visitCount += 1;
    customer.lastVisit = visit.date;
    active = null;
    notifyListeners();
    return visit;
  }
}

CareStepDraft _stepFromMap(Map<String, dynamic> raw) {
  final minutes = raw['minutes'];
  return CareStepDraft(
    title: raw['title']?.toString() ?? '',
    product: raw['product']?.toString() ?? '',
    device: raw['device']?.toString() ?? '',
    intensity: raw['intensity']?.toString() ?? '',
    minutes: minutes == null ? '' : '$minutes',
    area: raw['area']?.toString() ?? '',
    memo: raw['memo']?.toString() ?? '',
  );
}

String _axisId(String label) {
  for (final entry in ChartVisitRecord.axisLabel.entries) {
    if (entry.value == label || entry.key == label) return entry.key;
  }
  return label;
}

String formatVisitDay(DateTime date) {
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$m.$d';
}

String formatVisitFull(DateTime date) {
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '${date.year}.$m.$d';
}

String formatClock(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
