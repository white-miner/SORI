import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/customer_chart.dart';
import '../models/seminar_class.dart';
import '../services/shop_media_storage.dart';
import '../services/sori_store.dart';
import '../theme/sori_date_picker.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_nav.dart';
import '../widgets/seminar_chart_picker_sheet.dart';
import '../widgets/sori_insta_picker.dart';
import 'seminar_class_detail_page.dart';

/// 에듀케이터 세미나 개설/수정 폼 — duration, materials, linked chart, images.
class SeminarCreatePage extends StatefulWidget {
  const SeminarCreatePage({
    super.key,
    required this.store,
    this.targetCaseId,
    this.initialTitle = '',
    this.existing,
  });

  final SoriStore store;
  final String? targetCaseId;
  final String initialTitle;
  final SeminarClass? existing;

  static Future<void> open(
    BuildContext context, {
    required SoriStore store,
    String? targetCaseId,
    String initialTitle = '',
    SeminarClass? existing,
  }) {
    return pushRootPage<void>(
      context,
      SeminarCreatePage(
        store: store,
        targetCaseId: targetCaseId,
        initialTitle: initialTitle,
        existing: existing,
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
  final _materialInputCtrl = TextEditingController();

  DateTime? _eventDate;
  TimeOfDay _eventTime = const TimeOfDay(hour: 14, minute: 0);
  String _format = 'oneday';
  int _durationMinutes = 120;
  String? _linkedCaseId;
  final List<String> _materials = [];
  final List<String> _imageUrls = [];
  final List<Uint8List> _pendingImageBytes = [];
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
    final existing = widget.existing;
    if (existing != null) {
      _titleCtrl.text = existing.title;
      _locationCtrl.text = existing.location;
      _priceCtrl.text = '${existing.price}';
      _capacityCtrl.text = '${existing.maxCapacity}';
      _curriculumCtrl.text = existing.description;
      _format = existing.classFormat.trim().isEmpty
          ? 'oneday'
          : existing.classFormat;
      _durationMinutes = existing.durationMinutes;
      _linkedCaseId = existing.targetCaseId;
      _materials.addAll(existing.providedMaterials);
      _imageUrls.addAll(existing.additionalImages);
      final when = existing.eventDate;
      if (when != null) {
        _eventDate = DateTime(when.year, when.month, when.day);
        _eventTime = TimeOfDay(hour: when.hour, minute: when.minute);
      }
    } else {
      final seed = widget.initialTitle.trim();
      _titleCtrl.text = seed.isEmpty ? '' : '$seed 세미나';
      _linkedCaseId = widget.targetCaseId;
      final base = DateTime.now().add(const Duration(days: 14));
      _eventDate = DateTime(base.year, base.month, base.day);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _priceCtrl.dispose();
    _capacityCtrl.dispose();
    _curriculumCtrl.dispose();
    _materialInputCtrl.dispose();
    super.dispose();
  }

  CustomerChart? get _linkedChart {
    final id = _linkedCaseId?.trim();
    if (id == null || id.isEmpty) return null;
    for (final c in widget.store.charts) {
      if (c.id == id) return c;
    }
    return null;
  }

  String get _linkedChartLabel {
    final chart = _linkedChart;
    if (chart == null) return '연동된 게시물 없음';
    final title = chart.careName.trim().isNotEmpty
        ? chart.careName.trim()
        : chart.treatmentSummary.trim();
    return title.isEmpty ? 'B/A 케이스 연동됨' : title;
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

  Future<void> _pickLinkedChart() async {
    final picked = await showSeminarChartPickerSheet(
      context,
      store: widget.store,
      selectedChartId: _linkedCaseId,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _linkedCaseId = picked.trim().isEmpty ? null : picked.trim();
    });
  }

  Future<void> _addPhotos() async {
    final bytes = await openSoriInstaPicker(
      context,
      maxAssets: 8 - _imageUrls.length - _pendingImageBytes.length,
      title: '세미나 사진',
    );
    if (bytes.isEmpty || !mounted) return;
    setState(() => _pendingImageBytes.addAll(bytes));
  }

  void _removeImageUrl(int index) {
    setState(() => _imageUrls.removeAt(index));
  }

  void _removePendingImage(int index) {
    setState(() => _pendingImageBytes.removeAt(index));
  }

  void _addMaterial([String? raw]) {
    final value = (raw ?? _materialInputCtrl.text).trim();
    if (value.isEmpty) return;
    if (_materials.any((m) => m.toLowerCase() == value.toLowerCase())) return;
    setState(() {
      _materials.add(value);
      _materialInputCtrl.clear();
    });
  }

  DateTime? get _combinedDateTime {
    final d = _eventDate;
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day, _eventTime.hour, _eventTime.minute);
  }

  Future<List<String>> _uploadPendingImages(String shopId) async {
    final urls = <String>[];
    for (final bytes in _pendingImageBytes) {
      final url = await ShopMediaStorage.uploadSeminarImage(
        bytes: bytes,
        shopId: shopId,
      );
      if (url != null && url.trim().isNotEmpty) urls.add(url.trim());
    }
    return urls;
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
    final existing = widget.existing;
    final shopId = existing?.directorShopId ?? widget.store.shop.id;

    var imageUrls = List<String>.from(_imageUrls);
    if (_pendingImageBytes.isNotEmpty) {
      final uploaded = await _uploadPendingImages(shopId);
      imageUrls.addAll(uploaded);
    }

    var draft = SeminarClass(
      id: existing?.id ?? '',
      directorShopId: shopId,
      targetCaseId: _linkedCaseId,
      title: _titleCtrl.text.trim(),
      eventDate: _combinedDateTime,
      location: _locationCtrl.text.trim(),
      price: int.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0,
      maxCapacity: int.tryParse(_capacityCtrl.text) ?? 12,
      currentEnrollment: existing?.currentEnrollment ?? 0,
      status: existing?.status ?? SeminarClassStatus.open,
      description: _curriculumCtrl.text.trim(),
      classFormat: _format,
      durationMinutes: _durationMinutes,
      providedMaterials: List<String>.from(_materials),
      additionalImages: imageUrls,
      createdAt: existing?.createdAt,
    );

    final saved = existing == null
        ? await widget.store.createSeminarClass(draft)
        : await widget.store.updateSeminarClass(draft);
    if (!mounted) return;
    setState(() => _saving = false);

    if (saved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.store.lastError?.trim().isNotEmpty == true
                ? widget.store.lastError!
                : (existing == null
                    ? '세미나 개설에 실패했습니다.'
                    : '세미나 수정에 실패했습니다.'),
          ),
          backgroundColor: SoriTokens.systemRed,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null
              ? '「${saved.title}」 세미나가 개설되었습니다.'
              : '「${saved.title}」 세미나가 수정되었습니다.',
        ),
        backgroundColor: SoriTokens.primary,
      ),
    );
    Navigator.pop(context);
    if (existing != null || !context.mounted) return;
    await SeminarClassDetailPage.open(
      context,
      store: widget.store,
      classId: saved.id,
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
        title: Text(
          widget.existing == null ? '세미나 개설' : '세미나 수정',
          style: const TextStyle(fontWeight: FontWeight.w800),
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
            _SectionLabel('게시물 · 사진'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickLinkedChart,
              icon: const Icon(Icons.compare_arrows_rounded, size: 18),
              label: Text(_linkedChartLabel),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: SoriTokens.textPrimary,
                backgroundColor: SoriTokens.surface,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                side: const BorderSide(color: SoriTokens.outlinePurple),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 88,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < _imageUrls.length; i++)
                    _ImageThumb(
                      url: _imageUrls[i],
                      onRemove: () => _removeImageUrl(i),
                    ),
                  for (var i = 0; i < _pendingImageBytes.length; i++)
                    _ImageThumb(
                      bytes: _pendingImageBytes[i],
                      onRemove: () => _removePendingImage(i),
                    ),
                  _AddPhotoTile(onTap: _addPhotos),
                ],
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
            const _SectionLabel('클래스 형태'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SeminarClass.formatOptions.map((o) {
                final selected = _format == o.value;
                return ChoiceChip(
                  label: Text(
                    o.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? SoriTokens.onPrimary
                          : SoriTokens.tabUnselected,
                    ),
                  ),
                  selected: selected,
                  onSelected: (_) => setState(() => _format = o.value),
                  selectedColor: SoriTokens.primary,
                  backgroundColor: SoriTokens.chipIdleBg,
                  side: BorderSide.none,
                  showCheckmark: false,
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
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: _durationMinutes,
              decoration: _decoration('총 소요 시간'),
              items: [
                for (final o in SeminarClass.durationOptions)
                  DropdownMenuItem(value: o.minutes, child: Text(o.label)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _durationMinutes = v);
              },
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
            const SizedBox(height: 18),
            const _SectionLabel('교육 자재 및 제공 혜택'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _materials)
                  InputChip(
                    label: Text(m),
                    onDeleted: () => setState(() => _materials.remove(m)),
                  ),
                for (final s in SeminarClass.materialSuggestions)
                  if (!_materials.any((m) => m.toLowerCase() == s.toLowerCase()))
                    ActionChip(
                      label: Text('+ $s'),
                      onPressed: () => _addMaterial(s),
                    ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _materialInputCtrl,
                    decoration: _decoration('자재 직접 입력'),
                    onSubmitted: _addMaterial,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => _addMaterial(),
                  icon: const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: SoriTokens.primary,
                    foregroundColor: SoriTokens.onPrimary,
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
                  _saving
                      ? (widget.existing == null ? '개설 중…' : '저장 중…')
                      : (widget.existing == null ? '개설하기' : '수정 저장'),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({this.url, this.bytes, required this.onRemove});

  final String? url;
  final Uint8List? bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 80,
              height: 80,
              child: bytes != null
                  ? Image.memory(bytes!, fit: BoxFit.cover)
                  : Image.network(url!, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Material(
              color: SoriTokens.systemRed,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: SoriTokens.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: SoriTokens.outlinePurple),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: SoriTokens.primary),
            SizedBox(height: 4),
            Text(
              '사진 추가',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
