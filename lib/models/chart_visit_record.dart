import '../utils/db_map.dart';

/// CHART 방문 본문. 기존 `toDbWriteMap`에는 넣지 않는다.
/// 옛 저장이 이 칸을 null로 덮지 않게, 전용 patch만 쓴다.
class ChartVisitRecord {
  const ChartVisitRecord({
    this.flowStatus,
    this.visitDate,
    this.scores = const {},
    this.discomfortScore,
    this.concerns = const [],
    this.duration = '',
    this.desiredChange = '',
    this.safety = const {},
    this.consultGenerated = const {},
    this.consultApproved = const {},
    this.consultApplied = false,
    this.careGoals = const [],
    this.treatmentSteps = const [],
    this.reactionNone = true,
    this.reactionTypes = const [],
    this.aftercare = const [],
    this.homeAm = '',
    this.homePm = '',
    this.scoreChanges = const [],
    this.nextCareNote = '',
    this.nextCareTiming = '',
  });

  static const empty = ChartVisitRecord();

  static const scoreColumns = <String, String>{
    'hydration': 'score_hydration',
    'oil': 'score_oil',
    'sensitivity': 'score_sensitivity',
    'redness': 'score_redness',
    'keratin': 'score_keratin',
    'pores': 'score_pores',
    'pigmentation': 'score_pigmentation',
    'elasticity': 'score_elasticity',
    'acne': 'score_acne',
  };

  static const axisLabel = <String, String>{
    'hydration': '수분',
    'oil': '유분',
    'sensitivity': '민감',
    'redness': '홍조',
    'keratin': '각질',
    'pores': '모공',
    'pigmentation': '색소',
    'elasticity': '탄력',
    'acne': '트러블',
  };

  /// draft / completed. null 은 기존 방문.
  final String? flowStatus;
  final DateTime? visitDate;

  /// 1–5. 없는 축은 기록 전.
  final Map<String, int> scores;
  final int? discomfortScore;
  final List<String> concerns;
  final String duration;
  final String desiredChange;
  final Map<String, String> safety;
  final Map<String, String> consultGenerated;
  final Map<String, String> consultApproved;
  final bool consultApplied;
  final List<String> careGoals;
  final List<Map<String, dynamic>> treatmentSteps;
  final bool reactionNone;
  final List<String> reactionTypes;
  final List<String> aftercare;
  final String homeAm;
  final String homePm;

  /// axis id, from, to.
  final List<({String axis, int from, int to})> scoreChanges;
  final String nextCareNote;
  final String nextCareTiming;

  bool get isDraft => flowStatus == 'draft';

  bool get hasChartVisitBody =>
      flowStatus != null ||
      concerns.isNotEmpty ||
      careGoals.isNotEmpty ||
      scores.isNotEmpty ||
      scoreChanges.isNotEmpty ||
      safety.isNotEmpty;

  String get goalLine => careGoals.join(' · ');

  String get concernLine => concerns.join(' · ');

  String get changeLine => scoreChanges
      .map((c) => '${axisLabel[c.axis] ?? c.axis} ${c.from} → ${c.to}')
      .join(' · ');

  static int? _score(dynamic raw) {
    if (raw == null) return null;
    final n = raw is num ? raw.toInt() : int.tryParse('$raw');
    if (n == null || n < 1 || n > 5) return null;
    return n;
  }

  static Map<String, String> _stringMap(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String, String>{};
    raw.forEach((key, value) {
      final text = value?.toString() ?? '';
      if (text.isNotEmpty) out['$key'] = text;
    });
    return out;
  }

  factory ChartVisitRecord.fromMap(Map<String, dynamic> map) {
    final scores = <String, int>{};
    for (final entry in scoreColumns.entries) {
      final n = _score(map[entry.value]);
      if (n != null) scores[entry.key] = n;
    }

    final intake = map['visit_intake'];
    final intakeMap = intake is Map ? Map<String, dynamic>.from(intake) : null;
    final consult = map['consult_record'];
    final consultMap =
        consult is Map ? Map<String, dynamic>.from(consult) : null;
    final generated = consultMap?['generated'];
    final approved = consultMap?['approved'];
    final goals = DbMap.asStringList(map['care_goals']);
    final aftercare = DbMap.asStringList(map['aftercare']);
    final home = map['home_care_plan'];
    final homeMap = home is Map ? Map<String, dynamic>.from(home) : null;
    final reactions = map['care_reactions'];
    final reactionMap =
        reactions is Map ? Map<String, dynamic>.from(reactions) : null;
    final stepsRaw = map['treatment_steps'];
    final steps = <Map<String, dynamic>>[];
    if (stepsRaw is List) {
      for (final item in stepsRaw) {
        if (item is Map) steps.add(Map<String, dynamic>.from(item));
      }
    }
    final changesRaw = map['score_changes'];
    final changes = <({String axis, int from, int to})>[];
    if (changesRaw is List) {
      for (final item in changesRaw) {
        if (item is! Map) continue;
        final axis = item['axis']?.toString() ?? '';
        final from = _score(item['from']);
        final to = _score(item['to']);
        if (axis.isEmpty || from == null || to == null) continue;
        changes.add((axis: axis, from: from, to: to));
      }
    }
    final safety = _stringMap(map['safety_snapshot']);
    final status = DbMap.asTextOrNull(map['chart_flow_status']);

    return ChartVisitRecord(
      flowStatus: status == 'draft' || status == 'completed' ? status : null,
      visitDate: DbMap.asDateTime(map['visit_date']),
      scores: scores,
      discomfortScore: _score(map['discomfort_score']),
      concerns: DbMap.asStringList(intakeMap?['concerns']),
      duration: DbMap.asText(intakeMap?['duration']),
      desiredChange: DbMap.asText(intakeMap?['desired_change']),
      safety: safety,
      consultGenerated: _stringMap(generated),
      consultApproved: _stringMap(approved),
      consultApplied: consultMap?['applied'] == true,
      careGoals: goals,
      treatmentSteps: steps,
      reactionNone: reactionMap == null
          ? true
          : reactionMap['has_reaction'] != true,
      reactionTypes: DbMap.asStringList(reactionMap?['types']),
      aftercare: aftercare,
      homeAm: DbMap.asText(homeMap?['am']),
      homePm: DbMap.asText(homeMap?['pm']),
      scoreChanges: changes,
      nextCareNote: DbMap.asText(map['next_care_note']),
      nextCareTiming: DbMap.asText(map['next_care_timing']),
    );
  }

  /// 방문 patch. `visit_checked` 는 포함하지 않는다.
  Map<String, dynamic> toPatch({String? flowStatus}) {
    final status = flowStatus ?? this.flowStatus;
    final patch = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (status == 'draft' || status == 'completed')
        'chart_flow_status': status,
      'discomfort_score': discomfortScore,
      'visit_intake': {
        'concerns': concerns,
        'duration': duration,
        'desired_change': desiredChange,
      },
      'safety_snapshot': safety,
      'consult_record': {
        'generated': {
          'main_concerns': consultGenerated['main_concerns'] ?? '',
          'homecare': consultGenerated['homecare'] ?? '',
          'director_assessment': consultGenerated['director_assessment'] ?? '',
          'desired_change': consultGenerated['desired_change'] ?? '',
        },
        'approved': {
          'main_concerns': consultApproved['main_concerns'] ?? '',
          'homecare': consultApproved['homecare'] ?? '',
          'director_assessment': consultApproved['director_assessment'] ?? '',
          'desired_change': consultApproved['desired_change'] ?? '',
        },
        'applied': consultApplied,
      },
      'care_goals': careGoals,
      'treatment_steps': treatmentSteps,
      'care_reactions': {
        'has_reaction': !reactionNone && reactionTypes.isNotEmpty,
        'types': reactionTypes,
        'memo': '',
      },
      'score_changes': [
        for (final change in scoreChanges)
          {'axis': change.axis, 'from': change.from, 'to': change.to},
      ],
      'aftercare': aftercare,
      'home_care_plan': {'am': homeAm, 'pm': homePm},
      'next_care_note': nextCareNote,
      'next_care_timing': nextCareTiming,
    };
    for (final entry in scoreColumns.entries) {
      patch[entry.value] = scores[entry.key];
    }
    if (visitDate != null) {
      final d = visitDate!;
      patch['visit_date'] =
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }
    return patch;
  }

  Map<String, dynamic> customerSafetyPatch() {
    String? text(String key) {
      final value = safety[key]?.trim() ?? '';
      return value.isEmpty ? null : value;
    }

    return {
      'allergy_notes': text('allergy') ?? '',
      'medication_history': text('medication') ?? '',
      'medical_condition': text('condition'),
      'pregnancy_status': text('pregnancy'),
      'recent_procedure': text('recent_procedure'),
      'active_product': text('active_product'),
      'skin_trait': text('skin_trait'),
      'safety_note': text('safety_note'),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
