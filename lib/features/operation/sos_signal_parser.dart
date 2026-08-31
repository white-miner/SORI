import '../../models/customer.dart';
import '../../models/customer_chart.dart';
import '../../visit_kernel/models/care_schedule_entry.dart';
import 'models/sos_signal.dart';

/// PO PRD v4.0 — 예약 메모·알레르기·차트 이력 기반 SOS 스캔.
class SosSignalParser {
  SosSignalParser(this._rules);

  final List<SosKeywordRule> _rules;

  SosSignal scan({
    CareScheduleEntry? schedule,
    Customer? customer,
    CustomerChart? priorChart,
  }) {
    final corpus = <String, String>{};

    void add(String source, String? text) {
      final t = text?.trim() ?? '';
      if (t.isEmpty) return;
      corpus[source] = '${corpus[source] ?? ''} $t';
    }

    add('note', schedule?.note);
    add('note', schedule?.careLabel);
    add('allergy', customer?.allergyNotes);
    add('chart', priorChart?.allergyNotes);
    add('chart', priorChart?.sideEffectHistory);
    add('chart', priorChart?.skinSensitivity);

    if (corpus.isEmpty) return SosSignal.none;

    SosGrade maxGrade = SosGrade.clear;
    SosKeywordRule? bestRule;
    final matched = <String>[];
    final sources = <String>[];

    for (final entry in corpus.entries) {
      final lower = entry.value.toLowerCase();
      for (final rule in _rules) {
        final kw = rule.keyword.trim().toLowerCase();
        if (kw.isEmpty) continue;
        if (!lower.contains(kw)) continue;
        matched.add(kw);
        sources.add(entry.key);
        if (rule.grade.index > maxGrade.index) {
          maxGrade = rule.grade;
          bestRule = rule;
        } else if (rule.grade == maxGrade && bestRule == null) {
          bestRule = rule;
        }
      }
    }

    if (maxGrade == SosGrade.clear || bestRule == null) {
      return SosSignal.none;
    }

    return SosSignal(
      grade: maxGrade,
      headline: bestRule.headline,
      narrative: bestRule.narrative,
      sources: sources.toSet().toList(growable: false),
      matchedKeywords: matched.toSet().toList(growable: false),
    );
  }
}

List<SosKeywordRule> mergeSosRules({
  List<SosKeywordRule> shopRules = const [],
}) {
  final byKeyword = <String, SosKeywordRule>{};
  for (final r in defaultSosKeywordRules) {
    byKeyword[r.keyword.trim().toLowerCase()] = r;
  }
  for (final r in shopRules) {
    final key = r.keyword.trim().toLowerCase();
    if (key.isEmpty) continue;
    byKeyword[key] = r;
  }
  return byKeyword.values.toList(growable: false);
}
