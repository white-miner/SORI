import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/seminar_class.dart';
import '../services/sori_store.dart';
import '../theme/sori_date_picker.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_nav.dart';
import 'seminar_class_detail_page.dart';

/// 에듀케이터 세미나 개설 폼 — `seminar_classes`(seminars 뷰) INSERT.
class SeminarCreatePage extends StatefulWidget {
  const SeminarCreatePage({
    super.key,
    required this.store,
    this.targetCaseId,
    this.initialTitle = '',
  });

  final SoriStore store;
  final String? targetCaseId;
  final String initialTitle;

  static Future<void> open(
    BuildContext context, {
    required SoriStore store,
    String? targetCaseId,
    String initialTitle = '',
  }) {
    return pushRootPage<void>(
      context,
      SeminarCreatePage(
        store: store,
        targetCaseId: targetCaseId,
        initialTitle: initialTitle,
      ),
    );
  }

  @override
  State<SeminarCreatePage> createState() => _SeminarCreatePageState();
}

class _SeminarCreatePageState extends State<SeminarCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '150000');
  final _capacityCtrl = TextEditingController(text: '12');
  final _curriculumCtrl = TextEditingController();

  DateTime? _eventDate;
  TimeOfDay _eventTime = const TimeOfDay(hour: 14, minute: 0);
  String _format = 'oneday';
  bool _saving = false;

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: SoriTokens.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SoriTokens.outlinePurple),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SoriTokens.primary, width: 1.4),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final seed = widget.initialTitle.trim();
    _titleCtrl.text = seed.isEmpty ? '' : '$seed 세미나';
    final base = DateTime.now().add(const Duration(days: 14));
    _eventDate = DateTime(base.year, base.month, base.day);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _priceCtrl.dispose();
    _capacityCtrl.dispose();
    _curriculumCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await SoriDatePickerTheme.show(
      context: context,
      initialDate: _eventDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: '세미나 일시',
    );
    if (picked != null) setState(() => _eventDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _eventTime,
      helpText: '시작 시간',
    );
    if (picked != null) setState(() => _eventTime = picked);
  }

  DateTime? get _combinedDateTime {
    final d = _eventDate;
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day, _eventTime.hour, _eventTime.minute);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_eventDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일시를 선택해 주세요.')),
      );
      return;
    }

    setState(() => _saving = true);
    final draft = SeminarClass(
      id: '',
      directorShopId: widget.store.shop.id,
      targetCaseId: widget.targetCaseId,
      title: _titleCtrl.text.trim(),
      eventDate: _combinedDateTime,
      location: _locationCtrl.text.trim(),
      price: int.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0,
      maxCapacity: int.tryParse(_capacityCtrl.text) ?? 12,
      status: SeminarClassStatus.open,
      description: _curriculumCtrl.text.trim(),
      classFormat: _format,
    );

    final created = await widget.store.createSeminarClass(draft);
    if (!mounted) return;
    setState(() => _saving = false);

    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.store.lastError?.trim().isNotEmpty == true
                ? widget.store.lastError!
                : '세미나 개설에 실패했습니다.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${created.title}」 세미나가 개설되었습니다.'),
        backgroundColor: SoriTokens.primary,
      ),
    );
    Navigator.pop(context);
    if (!context.mounted) return;
    await SeminarClassDetailPage.open(
      context,
      store: widget.store,
      classId: created.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _eventDate == null
        ? '날짜 선택'
        : '${_eventDate!.year}.${_eventDate!.month.toString().padLeft(2, '0')}.${_eventDate!.day.toString().padLeft(2, '0')}';
    final timeLabel =
        '${_eventTime.hour.toString().padLeft(2, '0')}:${_eventTime.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: const Text(
          '세미나 개설',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: SoriTokens.surface,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SoriTokens.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SoriTokens.outlinePurple),
              ),
              child: const Text(
                '수요가 확인된 케이스를 기반으로 클래스를 오픈하세요. 수강료는 에스크로로 보관됩니다.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _titleCtrl,
              decoration: _decoration('세미나 제목', hint: '시그니처 관리 케이스 세미나'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '제목을 입력해 주세요.' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            const Text(
              '클래스 형태',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SeminarClass.formatOptions.map((o) {
                final selected = _format == o.value;
                return ChoiceChip(
                  label: Text(o.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _format = o.value),
                  selectedColor: SoriTokens.primarySoft,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selected ? SoriTokens.primary : SoriTokens.textSecondary,
                  ),
                  side: BorderSide(
                    color: selected
                        ? SoriTokens.primary.withValues(alpha: 0.5)
                        : SoriTokens.border,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(dateLabel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SoriTokens.textPrimary,
                      backgroundColor: SoriTokens.surface,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: SoriTokens.outlinePurple),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule_outlined, size: 18),
                    label: Text(timeLabel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SoriTokens.textPrimary,
                      backgroundColor: SoriTokens.surface,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: SoriTokens.outlinePurple),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _locationCtrl,
              decoration: _decoration('장소', hint: '샵 실습실 / 온라인 Zoom 등'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '장소를 입력해 주세요.' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _capacityCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _decoration('모집 인원'),
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      if (n == null || n < 1) return '1명 이상';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _decoration('수강료 (원)'),
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      if (n == null || n < 0) return '금액을 입력';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _curriculumCtrl,
              minLines: 5,
              maxLines: 8,
              decoration: _decoration(
                '상세 커리큘럼',
                hint: '시간표, 실습 포인트, 준비물 등을 적어 주세요.',
              ),
              validator: (v) => (v == null || v.trim().length < 10)
                  ? '커리큘럼을 10자 이상 입력해 주세요.'
                  : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: SoriTokens.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _saving ? '개설 중…' : '개설하기',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
