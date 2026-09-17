import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../models/customer_chart.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import 'chart_paper_section.dart';
import 'chart_workspace_state.dart';

/// 신규 작성 본문. 저장 전 INSERT 없음. 저장 시 오늘 Chart 1건 생성.
class ChartNewVisitSheet extends StatefulWidget {
  const ChartNewVisitSheet({
    super.key,
    required this.store,
    required this.customer,
    required this.onSaved,
  });

  final SoriStore store;
  final Customer customer;
  final ValueChanged<CustomerChart> onSaved;

  @override
  State<ChartNewVisitSheet> createState() => _ChartNewVisitSheetState();
}

class _ChartNewVisitSheetState extends State<ChartNewVisitSheet> {
  late final TextEditingController _status;
  late final TextEditingController _needs;
  late final TextEditingController _consult;
  late final TextEditingController _service;
  late final TextEditingController _nextNote;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _status = TextEditingController();
    _needs = TextEditingController();
    _consult = TextEditingController();
    _service = TextEditingController();
    _nextNote = TextEditingController();
  }

  @override
  void dispose() {
    _status.dispose();
    _needs.dispose();
    _consult.dispose();
    _service.dispose();
    _nextNote.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final lines = _service.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final careName = lines.isEmpty ? '오늘 케어' : lines.first;
      final treatment = lines.length <= 1 ? '' : lines.sublist(1).join('\n');
      final statusLines = _status.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final visitNumber = widget.store.nextVisitNumber(widget.customer.id);

      final saved = await widget.store.saveChartAndConfirmVisitAsync(
        customerId: widget.customer.id,
        visitNumber: visitNumber,
        careName: careName,
        treatmentSummary: treatment,
        directorInsight: _consult.text.trim(),
        concernChips: const [],
        firstVisitFearChips: const [],
        revisitFeedbackChips: const [],
        allergyNotes: statusLines.isNotEmpty ? statusLines.first : '',
        skinSensitivity: statusLines.length > 1 ? statusLines[1] : '',
        sideEffectHistory: statusLines.length > 2
            ? statusLines.sublist(2).join('\n')
            : '',
        customerRequests: _needs.text.trim(),
      );
      widget.onSaved(saved);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('오늘 기록지를 저장했습니다')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = formatChartDate(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '신규 작성 · $date',
                  key: const Key('chart-new-sheet-title'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              FilledButton(
                key: const Key('chart-new-sheet-save'),
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: SoriTokens.textCharcoal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(72, 40),
                ),
                child: Text(_saving ? '저장 중' : '저장'),
              ),
            ],
          ),
          ChartPaperSection(
            title: '고객 상태',
            child: TextField(
              key: const Key('chart-new-status'),
              controller: _status,
              maxLines: null,
              style: chartBodyTextStyle,
              decoration: chartFieldDecoration('상태·민감·주의사항을 기록'),
            ),
          ),
          ChartPaperSection(
            title: '니즈',
            child: TextField(
              key: const Key('chart-new-needs'),
              controller: _needs,
              maxLines: null,
              style: chartBodyTextStyle,
              decoration: chartFieldDecoration('고객이 원한 것'),
            ),
          ),
          ChartPaperSection(
            title: '상담',
            child: TextField(
              key: const Key('chart-new-consult'),
              controller: _consult,
              maxLines: null,
              style: chartBodyTextStyle,
              decoration: chartFieldDecoration('상담·인사이트'),
            ),
          ),
          ChartPaperSection(
            title: '제공 서비스',
            child: TextField(
              key: const Key('chart-new-service'),
              controller: _service,
              maxLines: null,
              style: chartBodyTextStyle,
              decoration: chartFieldDecoration('첫 줄 시술명, 다음 줄 요약'),
            ),
          ),
          const ChartPaperSection(
            title: '사진',
            child: Text('저장 후 파일철 사진에서 연결', style: chartBodyTextStyle),
          ),
          const ChartPaperSection(
            title: '결제',
            child: Text('결제는 파일철 결제 항목에서 확인', style: chartBodyTextStyle),
          ),
          ChartPaperSection(
            title: '다음 방문 참고',
            child: TextField(
              key: const Key('chart-new-next'),
              controller: _nextNote,
              maxLines: null,
              style: chartBodyTextStyle,
              decoration: chartFieldDecoration('다음 방문에 남길 참고'),
            ),
          ),
        ],
      ),
    );
  }
}
