import 'dart:convert';

import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';
import 'chart_visit_mock.dart';

/// Approval depends on today's intake, never on the actual treatment steps.
String visitConsultationInputSignature(ChartVisitSession s) => jsonEncode([
  s.concerns,
  s.since,
  s.discomfort,
  s.desiredChange,
  s.revisitFeedback,
  s.scores,
  s.safety.allergy,
  s.safety.medication,
  s.safety.condition,
  s.safety.pregnancy,
  s.safety.recentProcedure,
  s.safety.activeProduct,
]);

/// Read the same visit's approved consultation without copying it into care.
class ConsultationCareContext extends StatelessWidget {
  const ConsultationCareContext({
    super.key,
    required this.session,
    required this.onEdit,
  });

  final ChartVisitSession session;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final hasText = [
      s.summaryConcerns,
      s.summaryLife,
      s.summaryJudgement,
      s.summaryWish,
    ].any((text) => text.trim().isNotEmpty);
    final applied = s.consultApplied && hasText;
    return Column(
      key: const Key('care-consult-context'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '상담에서 확인한 방향',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          applied
              ? '오늘 상담 · 차트에 적용됨'
              : hasText && s.consult == ConsultPhase.summarized
              ? '상담 내용 확인·적용 필요'
              : '상담 기록 없음',
        ),
        if (applied) ...[
          _ContextLine('관리사 판단', s.summaryJudgement),
          _ContextLine('고객이 원하는 변화', s.summaryWish),
        ],
        TextButton(
          key: const Key('care-open-consult'),
          style: TextButton.styleFrom(
            foregroundColor: SoriTokens.textPrimary,
            alignment: Alignment.centerLeft,
          ),
          onPressed: onEdit,
          child: Text(applied ? '상담 확인·수정' : '상담 기록 열기'),
        ),
        Material(
          color: Colors.transparent,
          child: ExpansionTile(
            key: const PageStorageKey('care-safety-context'),
            tilePadding: EdgeInsets.zero,
            title: const Text(
              '방문 안전정보 · 오늘 확인 여부 미확인',
              style: TextStyle(fontSize: 14),
            ),
            children: [
              _ContextLine('알레르기', s.safety.allergy, empty: '미확인'),
              _ContextLine('복용약', s.safety.medication, empty: '미확인'),
              _ContextLine('현재 질환', s.safety.condition, empty: '미확인'),
              _ContextLine('임신 / 수유', s.safety.pregnancy, empty: '미확인'),
              _ContextLine('최근 시술', s.safety.recentProcedure, empty: '미확인'),
              _ContextLine('기능성 제품', s.safety.activeProduct, empty: '미확인'),
            ],
          ),
        ),
        const Divider(height: 28),
      ],
    );
  }
}

/// Treatment titles, areas and reactions are references, not new result values.
class PerformedCareContext extends StatelessWidget {
  const PerformedCareContext({
    super.key,
    required this.session,
    required this.onEdit,
  });
  final ChartVisitSession session;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final steps = session.steps
        .where(
          (s) =>
              s.title.trim().isNotEmpty ||
              s.memo.trim().isNotEmpty ||
              s.area.trim().isNotEmpty,
        )
        .toList();
    return Column(
      key: const Key('result-care-context'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '오늘 기록한 관리',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (steps.isEmpty) const Text('관리 내용 기록 없음'),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '${i + 1}. ${steps[i].title.trim().isEmpty ? '이름 미기록' : steps[i].title.trim()}'
              '${steps[i].area.trim().isEmpty ? '' : ' · ${steps[i].area.trim()}'}',
            ),
          ),
        // Empty legacy reaction flags are not proof that no reaction occurred.
        _ContextLine(
          '관리 중 특이 반응',
          session.reactions.join(' · '),
          empty: '특이 반응 기록 없음',
        ),
        if (steps.any((s) => s.memo.trim().isNotEmpty))
          Material(
            color: Colors.transparent,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('관리 메모 보기', style: TextStyle(fontSize: 14)),
              children: [
                for (final step in steps)
                  if (step.memo.trim().isNotEmpty)
                    _ContextLine(step.title, step.memo),
              ],
            ),
          ),
        TextButton(
          key: const Key('result-open-care'),
          style: TextButton.styleFrom(
            foregroundColor: SoriTokens.textPrimary,
            alignment: Alignment.centerLeft,
          ),
          onPressed: onEdit,
          child: const Text('관리 내용 확인·수정'),
        ),
        const Divider(height: 28),
      ],
    );
  }
}

class _ContextLine extends StatelessWidget {
  const _ContextLine(this.label, this.value, {this.empty = '기록 없음'});
  final String label;
  final String value;
  final String empty;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '$label: ${value.trim().isEmpty ? empty : value.trim()}',
        style: const TextStyle(fontSize: 15, height: 1.45),
      ),
    ),
  );
}

int? visitBaseline(ChartVisitSession session, String label) {
  for (final axis in kSkinAxes) {
    if (axis.$2 == label || axis.$1 == label) {
      final value = session.scores[axis.$1];
      return value != null && value >= 1 && value <= 5 ? value : null;
    }
  }
  return null;
}

class VisitChangeRecords extends StatelessWidget {
  const VisitChangeRecords({
    super.key,
    required this.session,
    required this.onChanged,
  });
  final ChartVisitSession session;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final change in session.changes) ...[
        Text(
          '${change.axis}   ${change.from} → ${change.to}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        if (visitBaseline(session, change.axis) != change.from)
          const Text(
            '관리 전 기준 변경됨 · 변화 재확인',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: Key('visit-change-edit-${change.axis}'),
            style: TextButton.styleFrom(
              foregroundColor: SoriTokens.textPrimary,
            ),
            onPressed: () async {
              if (await showVisitScoreChange(
                context,
                session,
                existing: change,
              )) {
                onChanged();
              }
            },
            child: const Text('변화 확인·수정'),
          ),
        ),
      ],
    ],
  );
}

/// The baseline is read-only. Only an explicit save updates the comparison.
Future<bool> showVisitScoreChange(
  BuildContext context,
  ChartVisitSession session, {
  ScoreChange? existing,
}) async {
  var axis = existing?.axis ?? '홍조';
  var after = existing?.to ?? 0;
  final result = await showModalBottomSheet<ScoreChange>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheet) {
        final baseline = visitBaseline(session, axis);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '변화 기록',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('visit-change-axis'),
                  initialValue: axis,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '비교 항목'),
                  items: [
                    if (!kSkinAxes.any((a) => a.$2 == axis))
                      DropdownMenuItem(value: axis, child: Text(axis)),
                    for (final a in kSkinAxes)
                      DropdownMenuItem(value: a.$2, child: Text(a.$2)),
                  ],
                  onChanged: (value) => setSheet(() {
                    axis = value!;
                    after = 0;
                  }),
                ),
                const SizedBox(height: 20),
                Text(
                  baseline == null
                      ? '관리 전 점수 기록 없음'
                      : '오늘 문진 · 관리 전 $baseline/5',
                  key: const Key('visit-change-baseline'),
                ),
                if (baseline == null)
                  const Text(
                    '문진 기록에 관리 전 점수를 남긴 뒤 비교할 수 있습니다. 임의 점수는 넣지 않습니다.',
                  ),
                if (existing != null && existing.from != baseline)
                  Text('기존 비교 기준: ${existing.from}/5 · 저장하면 확인한 오늘 기준으로 바뀝니다.'),
                const SizedBox(height: 16),
                const Text('관리 후 · 직접 선택'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var n = 1; n <= 5; n++)
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: OutlinedButton(
                          key: Key('visit-change-after-$n'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: after == n
                                ? SoriTokens.textPrimary
                                : Colors.white,
                            foregroundColor: after == n
                                ? Colors.white
                                : SoriTokens.textPrimary,
                          ),
                          onPressed: () => setSheet(() => after = n),
                          child: Text('$n'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('visit-change-save'),
                  style: FilledButton.styleFrom(
                    backgroundColor: SoriTokens.textPrimary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: baseline == null || after < 1 || after > 5
                      ? null
                      : () => Navigator.pop(
                          sheetContext,
                          ScoreChange(axis: axis, from: baseline, to: after),
                        ),
                  child: const Text('변화 저장'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  style: TextButton.styleFrom(
                    foregroundColor: SoriTokens.textPrimary,
                  ),
                  child: const Text('취소'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  if (result == null) return false;
  // Keep one current comparison per axis without changing today's intake.
  final duplicate = session.changes.indexWhere((c) => c.axis == result.axis);
  if (existing != null) session.changes.remove(existing);
  session.changes.removeWhere((c) => c.axis == result.axis);
  final at = duplicate < 0
      ? session.changes.length
      : duplicate.clamp(0, session.changes.length);
  session.changes.insert(at, result);
  return true;
}
