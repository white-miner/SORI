import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';
import 'chart_visit_mock.dart';

/// Reads this visit's intake without copying it into consultation fields.
class ConsultationIntakeContext extends StatefulWidget {
  const ConsultationIntakeContext({
    super.key,
    required this.session,
    required this.onEdit,
    required this.onEditSafety,
    this.onFeedbackChanged,
  });

  final ChartVisitSession session;
  final VoidCallback onEdit;
  final VoidCallback onEditSafety;
  final VoidCallback? onFeedbackChanged;

  @override
  State<ConsultationIntakeContext> createState() =>
      _ConsultationIntakeContextState();
}

class _ConsultationIntakeContextState extends State<ConsultationIntakeContext> {
  bool _expanded = false;

  Widget _pastContext(ChartVisitSession session) {
    final visits = ChartVisitPreviewStore.instance.history.where((visit) {
      if (visit.id == session.id || visit.record.isDraft) return false;
      if (!visit.hasKnownDate) return true;
      final today = session.startedAt;
      return visit.date.isBefore(
        DateTime(today.year, today.month, today.day + 1),
      );
    }).toList();
    visits.sort((a, b) {
      if (a.hasKnownDate != b.hasKnownDate) return a.hasKnownDate ? -1 : 1;
      return b.date.compareTo(a.date);
    });
    if (visits.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Text('이전 기록 없음 · 오늘 문진을 보며 상담하세요.'),
      );
    }
    final past = visits.firstWhere(
      (visit) => visit.id == session.consultationPastVisitId,
      orElse: () => visits.first,
    );
    final record = past.record;
    final pastExpanded = session.consultationPastExpanded;
    num order(Map<String, dynamic> step) =>
        num.tryParse('${step['sort']}') ?? 0;
    final steps = record.treatmentSteps.toList()
      ..sort((a, b) => order(a).compareTo(order(b)));
    String text(dynamic value) => value?.toString().trim() ?? '';
    final care = steps
        .map((step) {
          final title = text(step['title']);
          final area = text(step['area']);
          return [
            title,
            if (area.isNotEmpty) '부위: $area',
          ].where((part) => part.isNotEmpty).join(' · ');
        })
        .where((line) => line.isNotEmpty)
        .join('\n');
    final actual = care.isNotEmpty ? care : past.performedCare;
    String day(PastVisit visit) =>
        visit.hasKnownDate ? formatVisitFull(visit.date) : '방문 날짜 미기록';
    return Column(
      key: const Key('consult-past-context'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        const Text(
          '지난 방문 기록 · 읽기 전용',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(day(past)),
        if (visits.length > 1)
          DropdownButton<String>(
            key: const Key('consult-past-select'),
            isExpanded: true,
            value: past.id,
            items: [
              for (final visit in visits)
                DropdownMenuItem(
                  value: visit.id,
                  child: Text(
                    '${day(visit)} · ${visit.performedCare.isEmpty ? '방문 기록' : visit.performedCare}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) =>
                setState(() => session.consultationPastVisitId = id),
          ),
        Text(
          '실제 관리: ${actual.isEmpty ? '기록 없음' : actual}',
          maxLines: pastExpanded ? null : 3,
          overflow: pastExpanded ? null : TextOverflow.ellipsis,
        ),
        Text(
          '관리 중 특이 반응: ${record.reactionTypes.isEmpty ? '기록 없음' : record.reactionTypes.join(' · ')}',
        ),
        Text(
          '당시 다음 계획: ${record.nextCareNote.isEmpty ? '기록 없음' : record.nextCareNote}',
        ),
        if (pastExpanded) ...[
          Text(
            '당시 관리 목표: ${record.goalLine.isEmpty ? '기록 없음' : record.goalLine}',
          ),
          Text('당시 변화: ${past.changeLine.isEmpty ? '기록 없음' : past.changeLine}'),
          Text('당시 홈케어 AM: ${record.homeAm.isEmpty ? '기록 없음' : record.homeAm}'),
          Text('당시 홈케어 PM: ${record.homePm.isEmpty ? '기록 없음' : record.homePm}'),
          Text(
            '당시 권장 시점: ${record.nextCareTiming.isEmpty ? '기록 없음' : record.nextCareTiming}',
          ),
          const SizedBox(height: 8),
          const Text(
            '지난 기록입니다. 오늘 상태나 지난 방문 이후의 반응으로 확정하지 않습니다.',
            style: TextStyle(fontSize: 13, color: SoriTokens.textSecondary),
          ),
        ],
        TextButton(
          key: const Key('consult-past-expand'),
          style: TextButton.styleFrom(foregroundColor: SoriTokens.textPrimary),
          onPressed: () =>
              setState(() => session.consultationPastExpanded = !pastExpanded),
          child: Text(pastExpanded ? '지난 기록 접기' : '지난 목표·변화·홈케어 보기'),
        ),
        const SizedBox(height: 8),
        const Text(
          '지난번 이후 어떠셨어요?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(
          '오늘 확인 · ${day(past)} 방문 이후의 고객 반응',
          style: const TextStyle(fontSize: 13, color: SoriTokens.textSecondary),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('revisit-feedback-${session.id}-${past.id}'),
          initialValue: session.revisitFeedback[past.id] ?? '',
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '변화가 얼마나 이어졌는지, 새 불편이나 홈케어 실천 여부',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            if (value.trim().isEmpty) {
              session.revisitFeedback.remove(past.id);
            } else {
              session.revisitFeedback[past.id] = value;
            }
            session.consultApplied = false;
            widget.onFeedbackChanged?.call();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final safety = <String, String>{
      '알레르기': s.safety.allergy,
      '복용약': s.safety.medication,
      '현재 질환': s.safety.condition,
      '임신 / 수유': s.safety.pregnancy,
      '최근 시술': s.safety.recentProcedure,
      '기능성 제품': s.safety.activeProduct,
    };
    return Container(
      key: const Key('consult-intake-context'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          color: SoriTokens.textPrimary,
          fontSize: 15,
          height: 1.45,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '오늘 문진 · 이번 방문 원문',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('고민: ${s.concerns.isEmpty ? '기록 없음' : s.concernLine}'),
            if (s.since.trim().isNotEmpty) Text('기간: ${s.since}'),
            if (s.discomfort > 0) Text('불편 정도: ${s.discomfort}/5'),
            if (s.desiredChange.trim().isNotEmpty)
              Text('원하는 변화: ${s.desiredChange}'),
            const SizedBox(height: 8),
            const Text(
              '안전정보 · 오늘 확인 여부 미확인',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            if (!_expanded)
              for (final entry in safety.entries)
                if (entry.value.trim().isNotEmpty &&
                    entry.value != '없음' &&
                    entry.value != '해당 없음')
                  Text('${entry.key}: ${entry.value}'),
            if (_expanded) ...[
              const Text(
                '저장된 값이며 오늘 확인 완료를 뜻하지 않습니다.',
                style: TextStyle(fontSize: 13, color: SoriTokens.textSecondary),
              ),
              for (final entry in safety.entries)
                Text(
                  '${entry.key}: ${entry.value.trim().isEmpty ? '미확인' : entry.value}',
                ),
              if (s.scores.values.any((value) => value > 0)) ...[
                const SizedBox(height: 8),
                const Text('관리사 피부 체크 · 입력한 점수'),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    for (final axis in kSkinAxes)
                      if ((s.scores[axis.$1] ?? 0) > 0)
                        Text('${axis.$2} ${s.scores[axis.$1]}/5'),
                  ],
                ),
              ],
            ],
            Wrap(
              spacing: 4,
              children: [
                TextButton(
                  key: const Key('consult-intake-expand'),
                  style: TextButton.styleFrom(
                    foregroundColor: SoriTokens.textPrimary,
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? '문진 상세 접기' : '문진 상세 펼치기'),
                ),
                TextButton(
                  key: const Key('consult-intake-edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: SoriTokens.textPrimary,
                  ),
                  onPressed: widget.onEdit,
                  child: const Text('문진 수정'),
                ),
                if (_expanded)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: SoriTokens.textPrimary,
                    ),
                    onPressed: widget.onEditSafety,
                    child: const Text('안전정보 수정'),
                  ),
              ],
            ),
            _pastContext(s),
          ],
        ),
      ),
    );
  }
}
