import 'package:flutter/material.dart';

import '../../models/customer_chart.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import 'chart_paper_section.dart';
import 'chart_workspace_state.dart';

/// 기존 Today / vNN Chart 본문. 동일 chart_id update만.
class ChartVisitSheet extends StatefulWidget {
  const ChartVisitSheet({
    super.key,
    required this.store,
    required this.chart,
    required this.isToday,
    required this.onSaved,
  });

  final SoriStore store;
  final CustomerChart chart;
  final bool isToday;
  final ValueChanged<CustomerChart> onSaved;

  @override
  State<ChartVisitSheet> createState() => _ChartVisitSheetState();
}

class _ChartVisitSheetState extends State<ChartVisitSheet> {
  late final TextEditingController _status = TextEditingController();
  late final TextEditingController _needs = TextEditingController();
  late final TextEditingController _consult = TextEditingController();
  late final TextEditingController _service = TextEditingController();
  late final TextEditingController _nextNote = TextEditingController();
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _bind(widget.chart);
  }

  @override
  void didUpdateWidget(covariant ChartVisitSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chart.id != widget.chart.id) {
      _bind(widget.chart);
    }
  }

  void _bind(CustomerChart chart) {
    _status.text = [
      chart.allergyNotes,
      chart.skinSensitivity,
      chart.sideEffectHistory,
    ].where((e) => e.trim().isNotEmpty).join('\n');
    _needs.text = [
      chart.customerRequests,
      if (chart.concernChips.isNotEmpty) chart.concernChips.join(', '),
    ].where((e) => e.trim().isNotEmpty).join('\n');
    _consult.text = chart.directorInsight;
    _service.text = [
      chart.careName,
      chart.treatmentSummary,
    ].where((e) => e.trim().isNotEmpty).join('\n');
    _nextNote.text = chart.homeCarePrescriptions.join(', ');
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
      final careName = lines.isEmpty ? widget.chart.careName : lines.first;
      final treatment = lines.length <= 1
          ? (lines.isEmpty ? widget.chart.treatmentSummary : '')
          : lines.sublist(1).join('\n');
      final statusLines = _status.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final saved = await widget.store.saveChartAndConfirmVisitAsync(
        customerId: widget.chart.customerId,
        visitNumber: widget.chart.visitNumber,
        chartId: widget.chart.id,
        careName: careName,
        treatmentSummary: treatment,
        directorInsight: _consult.text.trim(),
        concernChips: widget.chart.concernChips,
        firstVisitFearChips: widget.chart.firstVisitFearChips,
        revisitFeedbackChips: widget.chart.revisitFeedbackChips,
        allergyNotes: statusLines.isNotEmpty ? statusLines.first : '',
        skinSensitivity: statusLines.length > 1 ? statusLines[1] : '',
        sideEffectHistory: statusLines.length > 2
            ? statusLines.sublist(2).join('\n')
            : '',
        customerRequests: _needs.text.trim(),
        beforeImageUrl: widget.chart.beforeImageUrl,
        afterImageUrl: widget.chart.afterImageUrl,
        homeCarePrescriptions: widget.chart.homeCarePrescriptions,
        deviceInfo: widget.chart.deviceInfo,
      );
      widget.onSaved(saved);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('기록지를 저장했습니다')));
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
    final title = widget.isToday ? 'Today' : 'v${widget.chart.visitNumber}';
    final date = formatChartDate(chartVisitInstant(widget.chart));
    final before = widget.chart.beforeImageUrl?.trim() ?? '';
    final after = widget.chart.afterImageUrl?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$title · $date',
                  key: Key('chart-sheet-title-${widget.chart.id}'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              FilledButton(
                key: const Key('chart-sheet-save'),
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
              controller: _status,
              maxLines: null,
              style: chartBodyTextStyle,
              decoration: chartFieldDecoration('상태·민감·주의사항을 기록'),
            ),
          ),
          ChartPaperSection(
            title: '니즈',
            child: TextField(
              controller: _needs,
              maxLines: null,
              style: chartBodyTextStyle,
              decoration: chartFieldDecoration('고객이 원한 것'),
            ),
          ),
          ChartPaperSection(
            title: '상담',
            child: TextField(
              controller: _consult,
              maxLines: null,
              style: chartBodyTextStyle,
              decoration: chartFieldDecoration('상담·인사이트'),
            ),
          ),
          ChartPaperSection(
            title: '제공 서비스',
            child: TextField(
              controller: _service,
              maxLines: null,
              style: chartBodyTextStyle,
              decoration: chartFieldDecoration('첫 줄 시술명, 다음 줄 요약'),
            ),
          ),
          ChartPaperSection(
            title: '사진',
            child: Text(
              before.isEmpty && after.isEmpty
                  ? '사진 없음 · 파일철 사진 탭에서 확인'
                  : 'Before ${before.isEmpty ? '없음' : '있음'} · After ${after.isEmpty ? '없음' : '있음'}',
              style: chartBodyTextStyle,
            ),
          ),
          ChartPaperSection(
            title: '결제',
            child: const Text('결제는 파일철 결제 항목에서 확인', style: chartBodyTextStyle),
          ),
          ChartPaperSection(
            title: '다음 방문 참고',
            child: TextField(
              controller: _nextNote,
              maxLines: null,
              style: chartBodyTextStyle,
              decoration: chartFieldDecoration('다음 방문에 남길 참고'),
              readOnly: true,
            ),
          ),
        ],
      ),
    );
  }
}
