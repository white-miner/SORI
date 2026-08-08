import 'package:flutter/material.dart';

import '../models/chart_interview_chips.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../services/sori_store.dart';
import 'customer_link_popup.dart';
import 'my_app.dart';

/// 원장용 차트 작성 페이지 (심리 인터뷰 + 진단 + 방문 확인).
class AdminChartWriterPage extends StatefulWidget {
  const AdminChartWriterPage({
    super.key,
    required this.store,
    required this.customer,
    this.existingChart,
  });

  final SoriStore store;
  final Customer customer;
  final CustomerChart? existingChart;

  @override
  State<AdminChartWriterPage> createState() => _AdminChartWriterPageState();
}

class _AdminChartWriterPageState extends State<AdminChartWriterPage> {
  late int _visitNumber;
  late final TextEditingController _customNoController;
  late final TextEditingController _careNameController;
  late final TextEditingController _summaryController;
  late final TextEditingController _insightController;
  late final TextEditingController _beforeUrlController;
  late final TextEditingController _afterUrlController;

  final Set<String> _fears = {};
  final Set<String> _revisit = {};
  final Set<String> _concerns = {};
  bool _saving = false;

  bool get _isFirstVisit => _visitNumber <= 1;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingChart;
    _visitNumber =
        existing?.visitNumber ?? widget.store.nextVisitNumber(widget.customer.id);
    _customNoController =
        TextEditingController(text: existing?.customChartNo ?? '');
    _careNameController = TextEditingController(
      text: existing?.careName.isNotEmpty == true
          ? existing!.careName
          : widget.customer.treatmentType,
    );
    _summaryController =
        TextEditingController(text: existing?.treatmentSummary ?? '');
    _insightController =
        TextEditingController(text: existing?.directorInsight ?? '');
    _beforeUrlController =
        TextEditingController(text: existing?.beforeImageUrl ?? '');
    _afterUrlController =
        TextEditingController(text: existing?.afterImageUrl ?? '');
    _fears.addAll(existing?.firstVisitFearChips ?? const []);
    _revisit.addAll(existing?.revisitFeedbackChips ?? const []);
    _concerns.addAll(existing?.concernChips ?? const []);
  }

  @override
  void dispose() {
    _customNoController.dispose();
    _careNameController.dispose();
    _summaryController.dispose();
    _insightController.dispose();
    _beforeUrlController.dispose();
    _afterUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveAndConfirm() async {
    if (_careNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오늘 진행된 케어 명칭을 입력해 주세요.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final chart = widget.store.saveChartAndConfirmVisit(
        customerId: widget.customer.id,
        visitNumber: _visitNumber,
        customChartNo: _customNoController.text.trim().isEmpty
            ? null
            : _customNoController.text.trim(),
        chartId: widget.existingChart?.id,
        careName: _careNameController.text.trim(),
        treatmentSummary: _summaryController.text.trim().isEmpty
            ? '$_visitNumber회차 ${_careNameController.text.trim()}'
            : _summaryController.text.trim(),
        directorInsight: _insightController.text.trim(),
        concernChips: _concerns.toList(),
        firstVisitFearChips: _fears.toList(),
        revisitFeedbackChips: _revisit.toList(),
        beforeImageUrl: _beforeUrlController.text.trim().isEmpty
            ? null
            : _beforeUrlController.text.trim(),
        afterImageUrl: _afterUrlController.text.trim().isEmpty
            ? null
            : _afterUrlController.text.trim(),
      );

      if (!mounted) return;
      await showCustomerLinkPopup(context, chart: chart, store: widget.store);
      if (!mounted) return;
      Navigator.pop(context, chart);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        title: Text('${widget.customer.name} 차트 작성'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2D3436),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _sectionTitle('차트 번호 관리'),
          Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '자동 회차 (visit_number)',
                    border: OutlineInputBorder(),
                  ),
                  child: Text('$_visitNumber회차'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _customNoController,
                  decoration: const InputDecoration(
                    labelText: '수동 차트 번호',
                    hintText: 'custom_chart_no',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '전화번호 ${widget.customer.phone} 기준 타임라인에 $_visitNumber회차로 누적됩니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          _sectionTitle(
            _isFirstVisit
                ? '첫 방문 심리 인터뷰 (10초)'
                : '재방문 소소한 불편함 (말하기 미안해서 참았던 점)',
          ),
          if (!_isFirstVisit)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '원장님께 말하기 미안해서 참았던 소소한 불편함이 있으셨나요?',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (_isFirstVisit
                    ? ChartInterviewChips.firstVisitFears
                    : ChartInterviewChips.revisitFeedbacks)
                .map((label) {
              final selected =
                  _isFirstVisit ? _fears.contains(label) : _revisit.contains(label);
              return FilterChip(
                label: Text(label, style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    final set = _isFirstVisit ? _fears : _revisit;
                    if (v) {
                      set.add(label);
                    } else {
                      set.remove(label);
                    }
                  });
                },
                selectedColor: MyApp.soriPurple.withValues(alpha: 0.18),
                checkmarkColor: MyApp.soriPurple,
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          _sectionTitle('피부/바디 진단 & 원장 인사이트'),
          Text(
            '주요 고민 칩',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ChartInterviewChips.skinConcerns.map((label) {
              final selected = _concerns.contains(label);
              return FilterChip(
                label: Text(label, style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _concerns.add(label);
                    } else {
                      _concerns.remove(label);
                    }
                  });
                },
                selectedColor: MyApp.soriPurple.withValues(alpha: 0.18),
                checkmarkColor: MyApp.soriPurple,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _beforeUrlController,
            decoration: const InputDecoration(
              labelText: 'Before 사진 URL',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _afterUrlController,
            decoration: const InputDecoration(
              labelText: 'After 사진 URL',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _careNameController,
            decoration: const InputDecoration(
              labelText: '오늘 진행된 케어 명칭 *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _summaryController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '원장 맞춤 조치 / 시술 요약',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _insightController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'AI 답글용 한 줄 인사이트',
              hintText: '예: 민감 장벽 케어 강조, 홈케어 순한 제품 권장',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _saveAndConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: MyApp.soriPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _saving
                    ? '저장 중…'
                    : '차트 저장 및 방문 확인 완료 (visit_checked = true)',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, height: 1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2D3436),
        ),
      ),
    );
  }
}
