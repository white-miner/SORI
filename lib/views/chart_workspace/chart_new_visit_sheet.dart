import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/chart_interview_chips.dart';
import '../../models/customer.dart';
import '../../models/customer_chart.dart';
import '../../models/program_sales.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import 'chart_workspace_state.dart';

/// Chart「신규 작성」3스텝 위저드.
/// Step1 기본정보 · Step2 목적/결과/문제칩 · Step3 Programs 선택.
/// Desk / VisitLauncher 는 건드리지 않는다.
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
  static const _stepLabels = ['기본정보', '목적·결과', '프로그램'];

  var _step = 0;
  var _saving = false;

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _memo;
  late final TextEditingController _purposeNote;
  late final TextEditingController _resultNote;
  late final TextEditingController _careFallback;

  CustomerGender? _gender;
  final Set<String> _purposes = {};
  final Set<String> _desired = {};
  final Set<String> _concerns = {};
  String? _selectedPackageId;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _name = TextEditingController(text: c.name);
    _phone = TextEditingController(text: c.phone);
    _memo = TextEditingController(text: c.memo);
    _purposeNote = TextEditingController();
    _resultNote = TextEditingController();
    _careFallback = TextEditingController();
    _gender = c.gender;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _memo.dispose();
    _purposeNote.dispose();
    _resultNote.dispose();
    _careFallback.dispose();
    super.dispose();
  }

  List<ProgramPackage> get _activePackages {
    final list = widget.store.programPackages
        .where((p) => p.isActive)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  ProgramPackage? get _selectedPackage {
    final id = _selectedPackageId;
    if (id == null) return null;
    for (final p in _activePackages) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool _validateStep1() {
    if (_name.text.trim().isEmpty) {
      _toast('성함을 입력해 주세요');
      return false;
    }
    if (_phone.text.trim().isEmpty) {
      _toast('연락처를 입력해 주세요');
      return false;
    }
    return true;
  }

  bool _validateStep3() {
    if (_selectedPackage != null) return true;
    if (_careFallback.text.trim().isNotEmpty) return true;
    _toast('프로그램을 선택하거나 시술명을 입력해 주세요');
    return false;
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  void _goNext() {
    if (_step == 0 && !_validateStep1()) return;
    if (_step >= 2) return;
    setState(() => _step += 1);
  }

  void _goBack() {
    if (_step <= 0) return;
    setState(() => _step -= 1);
  }

  String _buildCustomerRequests() {
    final parts = <String>[];
    if (_purposes.isNotEmpty) {
      parts.add('방문 목적: ${_purposes.join(', ')}');
    }
    final pNote = _purposeNote.text.trim();
    if (pNote.isNotEmpty) parts.add('목적 메모: $pNote');
    if (_desired.isNotEmpty) {
      parts.add('원하는 결과: ${_desired.join(', ')}');
    }
    final rNote = _resultNote.text.trim();
    if (rNote.isNotEmpty) parts.add('결과 메모: $rNote');
    final memo = _memo.text.trim();
    if (memo.isNotEmpty) parts.add('메모: $memo');
    return parts.join('\n');
  }

  String _careName() {
    final pkg = _selectedPackage;
    if (pkg != null) return pkg.name;
    final fallback = _careFallback.text.trim();
    return fallback.isEmpty ? '오늘 케어' : fallback;
  }

  String _treatmentSummary() {
    final pkg = _selectedPackage;
    if (pkg == null) return '';
    final lines = <String>[
      if (pkg.visitCount > 0) '${pkg.visitCount}회 패키지',
      for (final line in pkg.lines.take(6))
        if (line.label.trim().isNotEmpty) line.label.trim(),
    ];
    return lines.join('\n');
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_validateStep1() || !_validateStep3()) return;
    setState(() => _saving = true);
    try {
      final visitNumber = widget.store.nextVisitNumber(widget.customer.id);
      final saved = await widget.store.saveChartAndConfirmVisitAsync(
        customerId: widget.customer.id,
        visitNumber: visitNumber,
        careName: _careName(),
        treatmentSummary: _treatmentSummary(),
        directorInsight: '',
        concernChips: _concerns.toList(),
        firstVisitFearChips: const [],
        revisitFeedbackChips: const [],
        customerName: _name.text.trim(),
        customerPhone: _phone.text.trim(),
        gender: _gender,
        customerRequests: _buildCustomerRequests(),
      );
      widget.onSaved(saved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오늘 기록지를 저장했습니다')),
        );
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
          Text(
            '신규 작성 · $date',
            key: const Key('chart-new-sheet-title'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _StepHeader(step: _step, labels: _stepLabels),
          const SizedBox(height: 12),
          _buildNavRow(),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(
              key: ValueKey('chart-new-step-$_step'),
              child: switch (_step) {
                0 => _buildStep1(),
                1 => _buildStep2(),
                _ => _buildStep3(),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavRow() {
    return Row(
      children: [
        if (_step > 0)
          TextButton(
            key: const Key('chart-new-back'),
            onPressed: _saving ? null : _goBack,
            child: const Text('이전'),
          ),
        const Spacer(),
        if (_step < 2)
          FilledButton(
            key: const Key('chart-new-next'),
            onPressed: _saving ? null : _goNext,
            style: FilledButton.styleFrom(
              backgroundColor: SoriTokens.brand,
              foregroundColor: SoriTokens.onBrand,
              minimumSize: const Size(96, 44),
            ),
            child: const Text('다음'),
          )
        else
          FilledButton(
            key: const Key('chart-new-sheet-save'),
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: SoriTokens.brand,
              foregroundColor: SoriTokens.onBrand,
              minimumSize: const Size(148, 44),
            ),
            child: Text(_saving ? '저장 중' : '저장하고 방문 확인'),
          ),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      key: const Key('chart-new-step-basic'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '오늘 기록할 고객의 기본 정보예요. 이름과 연락처만 확인하면 다음으로 갈 수 있어요.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: SoriTokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        _LabeledField(
          label: '성함',
          child: TextField(
            key: const Key('chart-new-name'),
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: _decoration('고객 성함'),
          ),
        ),
        _LabeledField(
          label: '연락처',
          child: TextField(
            key: const Key('chart-new-phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _decoration('010…'),
          ),
        ),
        const Text(
          '성별',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final g in CustomerGender.values)
              ChoiceChip(
                key: Key('chart-new-gender-${g.dbValue}'),
                label: Text(g.label),
                selected: _gender == g,
                onSelected: (_) => setState(() => _gender = g),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _LabeledField(
          label: '메모 (선택)',
          child: TextField(
            key: const Key('chart-new-memo'),
            controller: _memo,
            maxLines: 2,
            decoration: _decoration('알레르기·주의는 나중에 적어도 돼요'),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      key: const Key('chart-new-step-intent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '오늘은 왜 오셨고, 무엇을 원하시는지 골라 주세요. 칩만 눌러도 충분해요.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: SoriTokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        _ChipBlock(
          title: '방문 목적',
          options: ChartInterviewChips.visitPurposes,
          selected: _purposes,
          onToggle: (v) => setState(() {
            if (_purposes.contains(v)) {
              _purposes.remove(v);
            } else {
              _purposes.add(v);
            }
          }),
        ),
        TextField(
          key: const Key('chart-new-purpose-note'),
          controller: _purposeNote,
          decoration: _decoration('목적 한 줄 메모 (선택)'),
        ),
        const SizedBox(height: 12),
        _ChipBlock(
          title: '원하는 결과',
          options: ChartInterviewChips.desiredResults,
          selected: _desired,
          onToggle: (v) => setState(() {
            if (_desired.contains(v)) {
              _desired.remove(v);
            } else {
              _desired.add(v);
            }
          }),
        ),
        TextField(
          key: const Key('chart-new-result-note'),
          controller: _resultNote,
          decoration: _decoration('결과 한 줄 메모 (선택)'),
        ),
        const SizedBox(height: 12),
        _ChipBlock(
          title: '문제의식 · 주요 고민',
          options: ChartInterviewChips.skinConcerns,
          selected: _concerns,
          onToggle: (v) => setState(() {
            if (_concerns.contains(v)) {
              _concerns.remove(v);
            } else {
              _concerns.add(v);
            }
          }),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    final packages = _activePackages;
    return Column(
      key: const Key('chart-new-step-program'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '오늘 진행할 프로그램을 골라 주세요. Programs 탭에 등록된 패키지가 여기에 보여요.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: SoriTokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (packages.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SoriTokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SoriTokens.border),
            ),
            child: const Text(
              '아직 등록된 프로그램이 없어요. Programs 탭에서 패키지를 만들거나, 아래 시술명을 직접 적어 주세요.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('chart-new-service'),
            controller: _careFallback,
            decoration: _decoration('시술명 (예: 윤곽 관리)'),
          ),
        ] else ...[
          for (final pkg in packages) _programTile(pkg),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {
              _selectedPackageId = null;
            }),
            child: const Text('선택 해제 · 직접 시술명 입력'),
          ),
          if (_selectedPackageId == null)
            TextField(
              key: const Key('chart-new-service'),
              controller: _careFallback,
              decoration: _decoration('시술명 직접 입력'),
            ),
        ],
      ],
    );
  }

  Widget _programTile(ProgramPackage pkg) {
    final selected = _selectedPackageId == pkg.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? SoriTokens.brand.withValues(alpha: 0.08)
            : SoriTokens.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: Key('chart-new-program-${pkg.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() {
            _selectedPackageId = pkg.id;
            _careFallback.clear();
          }),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? SoriTokens.brand : SoriTokens.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 20,
                  color: selected ? SoriTokens.brand : SoriTokens.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pkg.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pkg.visitCount > 0
                            ? '${pkg.visitCount}회 · ${ProgramPricing.formatKrw(pkg.listPriceKrw)}원'
                            : '${ProgramPricing.formatKrw(pkg.listPriceKrw)}원',
                        style: const TextStyle(
                          fontSize: 12,
                          color: SoriTokens.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: SoriTokens.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SoriTokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SoriTokens.border),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.labels});

  final int step;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: i <= step
                    ? SoriTokens.brand
                    : SoriTokens.border,
              ),
            ),
          Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: i <= step
                    ? SoriTokens.brand
                    : SoriTokens.border,
                foregroundColor: i <= step
                    ? SoriTokens.onBrand
                    : SoriTokens.textSecondary,
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: i == step
                      ? SoriTokens.textCharcoal
                      : SoriTokens.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _ChipBlock extends StatelessWidget {
  const _ChipBlock({
    required this.title,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                FilterChip(
                  key: Key('chart-new-chip-$o'),
                  label: Text(o),
                  selected: selected.contains(o),
                  onSelected: (_) => onToggle(o),
                  selectedColor: SoriTokens.brand.withValues(alpha: 0.16),
                  checkmarkColor: SoriTokens.brand,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
