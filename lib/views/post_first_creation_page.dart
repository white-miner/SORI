import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../models/customer_chart.dart';
import '../models/omni_compose_category.dart';
import '../models/seminar_class.dart';
import '../models/session_user.dart';
import '../models/whisper.dart';
import '../services/openai_service.dart';
import '../services/sori_store.dart';
import '../theme/sori_date_picker.dart';
import '../theme/sori_tokens.dart';
import '../utils/consent_publish_gate.dart';
import '../utils/sori_nav.dart';
import '../widgets/post/post_view_data.dart';
import '../widgets/seminar_chart_picker_sheet.dart';
import '../widgets/sori_insta_picker.dart';

/// Omni-Composer — category chips + adaptive form + real CRUD submit.
class PostFirstCreationPage extends StatefulWidget {
  const PostFirstCreationPage({
    super.key,
    this.store,
    this.editTarget,
  });

  final SoriStore? store;
  final PostViewData? editTarget;

  static Future<void> open(BuildContext context, {SoriStore? store}) {
    return pushRootPage<void>(
      context,
      PostFirstCreationPage(store: store),
    );
  }

  static Future<void> openForEdit(
    BuildContext context, {
    required PostViewData data,
    SoriStore? store,
  }) {
    return pushRootPage<void>(
      context,
      PostFirstCreationPage(store: store, editTarget: data),
    );
  }

  @override
  State<PostFirstCreationPage> createState() => _PostFirstCreationPageState();
}

class _PostFirstCreationPageState extends State<PostFirstCreationPage> {
  late final SoriStore _store;
  OmniComposeCategory _category = OmniComposeCategory.whisper;
  bool _submitting = false;
  bool _aiLoading = false;

  final _whisperBody = TextEditingController();
  Uint8List? _whisperPhoto;

  Uint8List? _beforeBytes;
  Uint8List? _afterBytes;
  String? _linkedChartId;
  final _baBody = TextEditingController();

  final _seminarTitle = TextEditingController();
  final _seminarPrice = TextEditingController();
  final _seminarCapacity = TextEditingController(text: '12');
  final _seminarMaterials = TextEditingController();
  final _seminarCurriculum = TextEditingController();
  DateTime? _seminarDate;
  TimeOfDay _seminarTime = const TimeOfDay(hour: 14, minute: 0);

  final _reviewTitle = TextEditingController();
  final _reviewBody = TextEditingController();
  final _reviewPrice = TextEditingController();
  Uint8List? _reviewPhoto;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? SoriStore.instance;
    _prefillFromEditTarget();
  }

  bool get _isEditing => widget.editTarget != null;

  void _prefillFromEditTarget() {
    final data = widget.editTarget;
    if (data == null) return;
    _category = switch (data.kind) {
      PostViewKind.whisper => OmniComposeCategory.whisper,
      PostViewKind.ba => OmniComposeCategory.baShare,
      PostViewKind.seminar => OmniComposeCategory.seminar,
      PostViewKind.interior ||
      PostViewKind.deviceReview ||
      PostViewKind.marketplace =>
        OmniComposeCategory.reviewMarket,
    };
    switch (_category) {
      case OmniComposeCategory.whisper:
        _whisperBody.text = data.bodyText;
      case OmniComposeCategory.baShare:
        _baBody.text = data.bodyText;
        _linkedChartId = data.linkedChartId ?? data.caseItem?.chart.id;
      case OmniComposeCategory.seminar:
        final s = data.seminar;
        if (s != null) {
          _seminarTitle.text = s.title;
          _seminarPrice.text = '${s.price}';
          _seminarCapacity.text = '${s.maxCapacity}';
          _seminarCurriculum.text = s.description;
          _seminarMaterials.text = s.providedMaterials.join(', ');
          _linkedChartId = s.linkedChartId;
          if (s.eventDate != null) {
            _seminarDate = DateTime(
              s.eventDate!.year,
              s.eventDate!.month,
              s.eventDate!.day,
            );
            _seminarTime = TimeOfDay(
              hour: s.eventDate!.hour,
              minute: s.eventDate!.minute,
            );
          }
        }
      case OmniComposeCategory.reviewMarket:
        final p = data.post;
        _reviewTitle.text = p?.title ?? '';
        _reviewBody.text = data.bodyText;
        _reviewPrice.text = p?.listing != null ? '${p!.listing!.price}' : '';
    }
  }

  @override
  void dispose() {
    _whisperBody.dispose();
    _baBody.dispose();
    _seminarTitle.dispose();
    _seminarPrice.dispose();
    _seminarCapacity.dispose();
    _seminarMaterials.dispose();
    _seminarCurriculum.dispose();
    _reviewTitle.dispose();
    _reviewBody.dispose();
    _reviewPrice.dispose();
    super.dispose();
  }

  void _snack(String message, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? SoriTokens.systemRed : SoriTokens.primary,
      ),
    );
  }

  bool get _isDirector =>
      _store.session?.activeMode == UserRole.director;

  CustomerChart? get _linkedChart {
    final id = _linkedChartId?.trim();
    if (id == null || id.isEmpty) return null;
    for (final c in _store.charts) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _pickPhoto({required void Function(Uint8List bytes) onPicked}) async {
    final bytes = await openSoriInstaPicker(
      context,
      maxAssets: 1,
      title: '사진 첨부',
    );
    if (!mounted || bytes.isEmpty) return;
    onPicked(bytes.first);
  }

  Future<void> _pickLinkedChart() async {
    final picked = await showSeminarChartPickerSheet(
      context,
      store: _store,
      selectedChartId: _linkedChartId,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _linkedChartId = picked.trim().isEmpty ? null : picked.trim();
    });
  }

  Future<void> _generateAiSummary() async {
    if (_aiLoading) return;
    setState(() => _aiLoading = true);
    final care = _linkedChart?.careName.trim().isNotEmpty == true
        ? _linkedChart!.careName.trim()
        : (_baBody.text.trim().isEmpty ? '시술 케이스' : _baBody.text.trim());
    try {
      final service = OpenAiService();
      final text = service.isConfigured
          ? await service.composeReview(
              selectedChips: const ['비포애프터', '임상공유'],
              careName: care,
              directorComment: _baBody.text.trim(),
              shopName: _store.shop.name,
            )
          : OpenAiService.localFallback(
              selectedChips: const ['비포애프터', '임상공유'],
              careName: care,
              shopName: _store.shop.name,
            );
      if (!mounted) return;
      setState(() => _baBody.text = text);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_isDirector) {
      _snack('원장 전용 기능입니다. 원장 모드로 전환해 주세요.');
      return;
    }

    switch (_category) {
      case OmniComposeCategory.whisper:
        if (_whisperBody.text.trim().isEmpty) {
          _snack('제목이나 내용을 입력해 주세요.');
          return;
        }
      case OmniComposeCategory.baShare:
        final hasSlots = _beforeBytes != null && _afterBytes != null;
        final chart = _linkedChart;
        final chartHasBa = chart != null &&
            (chart.beforeImageUrl ?? '').trim().isNotEmpty &&
            (chart.afterImageUrl ?? '').trim().isNotEmpty;
        if (!hasSlots && !chartHasBa) {
          _snack('B/A 공유는 비포/애프터 사진이 필요합니다.');
          return;
        }
        if (_baBody.text.trim().isEmpty && chart == null) {
          _snack('제목이나 내용을 입력해 주세요.');
          return;
        }
      case OmniComposeCategory.seminar:
        if (_seminarTitle.text.trim().isEmpty) {
          _snack('제목이나 내용을 입력해 주세요.');
          return;
        }
        if (_seminarPrice.text.trim().isEmpty) {
          _snack('세미나 수강료를 입력해 주세요.');
          return;
        }
        if (_seminarDate == null) {
          _snack('세미나 일시를 선택해 주세요.');
          return;
        }
      case OmniComposeCategory.reviewMarket:
        if (_reviewTitle.text.trim().isEmpty &&
            _reviewBody.text.trim().isEmpty) {
          _snack('제목이나 내용을 입력해 주세요.');
          return;
        }
    }

    setState(() => _submitting = true);
    try {
      if (_isEditing) {
        await _submitEdit();
      } else {
        switch (_category) {
          case OmniComposeCategory.whisper:
            await _submitWhisper();
          case OmniComposeCategory.baShare:
            await _submitBa();
          case OmniComposeCategory.seminar:
            await _submitSeminar();
          case OmniComposeCategory.reviewMarket:
            await _submitReviewMarket();
        }
      }
    } catch (e) {
      if (mounted) _snack('작성 실패: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitEdit() async {
    final data = widget.editTarget!;
    switch (_category) {
      case OmniComposeCategory.whisper:
      case OmniComposeCategory.reviewMarket:
        if (data.post == null) {
          _snack('수정할 게시물을 찾을 수 없습니다.');
          return;
        }
        final ok = await _store.updateCommunityPostContent(
          postId: data.post!.id,
          body: _category == OmniComposeCategory.whisper
              ? _whisperBody.text.trim()
              : _reviewBody.text.trim(),
          title: _reviewTitle.text.trim(),
        );
        if (!mounted) return;
        if (!ok) {
          _snack(_store.lastError ?? '수정에 실패했습니다.');
          return;
        }
      case OmniComposeCategory.baShare:
        final chart = _linkedChart ?? data.caseItem?.chart;
        if (chart != null) {
          await _store.updateCustomerChartFields(
            chartId: chart.id,
            treatmentSummary: _baBody.text.trim(),
          );
          await _store.publishChartCaseToCommunity(
            chart,
            body: _baBody.text.trim(),
          );
        } else if (data.post != null) {
          final ok = await _store.updateCommunityPostContent(
            postId: data.post!.id,
            body: _baBody.text.trim(),
          );
          if (!mounted) return;
          if (!ok) {
            _snack(_store.lastError ?? '수정에 실패했습니다.');
            return;
          }
        }
      case OmniComposeCategory.seminar:
        final existing = data.seminar;
        if (existing == null) {
          _snack('수정할 세미나를 찾을 수 없습니다.');
          return;
        }
        final when = _seminarDate == null
            ? existing.eventDate
            : DateTime(
                _seminarDate!.year,
                _seminarDate!.month,
                _seminarDate!.day,
                _seminarTime.hour,
                _seminarTime.minute,
              );
        final materials = _seminarMaterials.text
            .split(RegExp(r'[,/\n]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        final saved = await _store.updateSeminarClass(
          existing.copyWith(
            title: _seminarTitle.text.trim(),
            eventDate: when,
            price: int.tryParse(_seminarPrice.text.replaceAll(',', '')) ?? 0,
            maxCapacity: int.tryParse(_seminarCapacity.text) ?? 12,
            description: _seminarCurriculum.text.trim(),
            providedMaterials: materials,
            targetCaseId: _linkedChartId,
          ),
        );
        if (!mounted) return;
        if (saved == null) {
          _snack(_store.lastError ?? '세미나 수정에 실패했습니다.');
          return;
        }
    }
    if (!mounted) return;
    _snack('게시물을 수정했습니다.', error: false);
    Navigator.of(context).pop();
  }

  Future<void> _submitWhisper() async {
    if (_whisperPhoto != null) {
      final post = await _store.createCommunityPost(
        postType: CommunityPostType.whisper,
        body: _whisperBody.text.trim(),
        imageBytesList: [_whisperPhoto!],
      );
      if (!mounted) return;
      if (post == null) {
        _snack(_store.lastError?.trim().isNotEmpty == true
            ? _store.lastError!
            : 'Whisper 게시에 실패했습니다.');
        return;
      }
    } else {
      await _store.sendWhisper(
        body: _whisperBody.text.trim(),
        spec: WhisperAudienceSpec(
          atoms: const [WhisperAtoms.everyone],
          shopId: _store.shop.id,
        ),
      );
    }
    if (!mounted) return;
    _snack('Whisper를 게시했습니다', error: false);
    Navigator.of(context).pop();
  }

  Future<void> _submitBa() async {
    final chart = _linkedChart;
    if (chart != null && canPublishBa(chart).allowsPublish) {
      final post = await _store.publishChartCaseToCommunity(
        chart,
        body: _baBody.text.trim(),
      );
      if (!mounted) return;
      if (post == null) {
        _snack(_store.lastError?.trim().isNotEmpty == true
            ? _store.lastError!
            : 'B/A 공유에 실패했습니다.');
        return;
      }
      _snack('B/A 케이스를 공유했습니다', error: false);
      Navigator.of(context).pop();
      return;
    }
    if (chart != null && !canPublishBa(chart).allowsPublish) {
      _snack(canPublishBa(chart).alertMessage);
      if (_beforeBytes == null || _afterBytes == null) return;
    }
    if (_beforeBytes == null || _afterBytes == null) {
      _snack('B/A 공유는 비포/애프터 사진이 필요합니다.');
      return;
    }
    final post = await _store.createCommunityPost(
      postType: CommunityPostType.caseShare,
      title: _linkedChart?.careName.trim() ?? '',
      body: _baBody.text.trim(),
      imageBytesList: [_beforeBytes!, _afterBytes!],
      sourceChartId: _linkedChartId,
    );
    if (!mounted) return;
    if (post == null) {
      _snack(_store.lastError?.trim().isNotEmpty == true
          ? _store.lastError!
          : 'B/A 공유에 실패했습니다.');
      return;
    }
    _snack('B/A 케이스를 공유했습니다', error: false);
    Navigator.of(context).pop();
  }

  Future<void> _submitSeminar() async {
    final when = DateTime(
      _seminarDate!.year,
      _seminarDate!.month,
      _seminarDate!.day,
      _seminarTime.hour,
      _seminarTime.minute,
    );
    final materials = _seminarMaterials.text
        .split(RegExp(r'[,/\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final saved = await _store.createSeminarClass(
      SeminarClass(
        id: '',
        directorShopId: _store.shop.id,
        title: _seminarTitle.text.trim(),
        eventDate: when,
        price: int.tryParse(_seminarPrice.text.replaceAll(',', '')) ?? 0,
        maxCapacity: int.tryParse(_seminarCapacity.text) ?? 12,
        description: _seminarCurriculum.text.trim(),
        providedMaterials: materials,
      ),
    );
    if (!mounted) return;
    if (saved == null) {
      _snack(_store.lastError?.trim().isNotEmpty == true
          ? _store.lastError!
          : '세미나 개설에 실패했습니다.');
      return;
    }
    _snack('세미나 모집을 등록했습니다', error: false);
    Navigator.of(context).pop();
  }

  Future<void> _submitReviewMarket() async {
    final title = _reviewTitle.text.trim();
    final body = _reviewBody.text.trim();
    final price = int.tryParse(_reviewPrice.text.replaceAll(',', '')) ?? 0;
    final post = await _store.createCommunityPost(
      postType: CommunityPostType.marketplace,
      title: title,
      body: body.isEmpty ? title : body,
      imageBytesList: _reviewPhoto == null ? null : [_reviewPhoto!],
      marketListing: MarketListingDraft(
        deviceName: title.isEmpty ? '중고 매물' : title,
        price: price,
      ),
    );
    if (!mounted) return;
    if (post == null) {
      _snack(_store.lastError?.trim().isNotEmpty == true
          ? _store.lastError!
          : '게시 실패했습니다.');
      return;
    }
    _snack('리뷰/중고 글을 등록했습니다', error: false);
    Navigator.of(context).pop();
  }

  InputDecoration _field(String label, {String? hint, int minLines = 1}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: minLines > 1,
      filled: true,
      fillColor: SoriTokens.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: SoriTokens.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: SoriTokens.primary, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        backgroundColor: SoriTokens.background,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
        title: Text(
          _isEditing ? '게시물 수정' : '새 게시물',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              key: const Key('omni-composer-submit'),
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: SoriTokens.primary,
                foregroundColor: SoriTokens.onPrimary,
                minimumSize: const Size(72, 40),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isEditing ? '저장' : '작성',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            _isEditing ? '게시물 수정' : '무엇을 공유할까요?',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: SoriTokens.textPrimary,
            ),
          ),
          if (!_isEditing) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in OmniComposeCategory.values)
                  ChoiceChip(
                    key: Key('omni-cat-${cat.name}'),
                    label: Text(cat.label),
                    selected: _category == cat,
                    onSelected: (_) => setState(() => _category = cat),
                    selectedColor: SoriTokens.primary,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _category == cat
                          ? SoriTokens.onPrimary
                          : SoriTokens.textPrimary,
                    ),
                    backgroundColor: SoriTokens.surface,
                    side: const BorderSide(color: SoriTokens.border),
                    showCheckmark: false,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey(_category),
              child: _buildForm(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return switch (_category) {
      OmniComposeCategory.whisper => _whisperForm(),
      OmniComposeCategory.baShare => _baForm(),
      OmniComposeCategory.seminar => _seminarForm(),
      OmniComposeCategory.reviewMarket => _reviewForm(),
    };
  }

  Widget _whisperForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('omni-whisper-body'),
          controller: _whisperBody,
          minLines: 5,
          maxLines: 10,
          decoration: _field('본문', hint: '지금 나누고 싶은 이야기를 적어 주세요', minLines: 5),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _pickPhoto(
            onPicked: (b) => setState(() => _whisperPhoto = b),
          ),
          icon: const Icon(Icons.photo_outlined),
          label: Text(_whisperPhoto == null ? '사진 첨부' : '사진 1장 선택됨'),
        ),
      ],
    );
  }

  Widget _baForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _PhotoSlot(
                label: 'Before',
                bytes: _beforeBytes,
                onTap: () => _pickPhoto(
                  onPicked: (b) => setState(() => _beforeBytes = b),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PhotoSlot(
                label: 'After',
                bytes: _afterBytes,
                onTap: () => _pickPhoto(
                  onPicked: (b) => setState(() => _afterBytes = b),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickLinkedChart,
          icon: const Icon(Icons.link_rounded),
          label: Text(
            _linkedChart == null
                ? '기존 차트 연동'
                : (_linkedChart!.careName.trim().isEmpty
                    ? '차트 연동됨'
                    : _linkedChart!.careName.trim()),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _baBody,
          minLines: 4,
          maxLines: 8,
          decoration: _field('본문', hint: '시술 포인트와 소감을 적어 주세요', minLines: 4),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _aiLoading ? null : _generateAiSummary,
          icon: _aiLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome_rounded),
          label: const Text('AI 요약 생성'),
        ),
      ],
    );
  }

  Widget _seminarForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('omni-seminar-title'),
          controller: _seminarTitle,
          decoration: _field('세미나 제목'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await SoriDatePickerTheme.show(
                    context: context,
                    initialDate: _seminarDate ?? now.add(const Duration(days: 7)),
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                    helpText: '세미나 일시',
                  );
                  if (picked != null) setState(() => _seminarDate = picked);
                },
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _seminarDate == null
                      ? '일시 선택'
                      : '${_seminarDate!.month}/${_seminarDate!.day}',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _seminarTime,
                  );
                  if (picked != null) setState(() => _seminarTime = picked);
                },
                icon: const Icon(Icons.schedule_outlined),
                label: Text(_seminarTime.format(context)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('omni-seminar-capacity'),
          controller: _seminarCapacity,
          keyboardType: TextInputType.number,
          decoration: _field('인원'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('omni-seminar-price'),
          controller: _seminarPrice,
          keyboardType: TextInputType.number,
          decoration: _field('수강료', hint: '원'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _seminarMaterials,
          decoration: _field('제공 자재', hint: '콤마로 구분해 입력'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _seminarCurriculum,
          minLines: 4,
          maxLines: 8,
          decoration: _field('커리큘럼', hint: '수업 구성과 목표', minLines: 4),
        ),
      ],
    );
  }

  Widget _reviewForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _reviewTitle,
          decoration: _field('제목', hint: '기기명 또는 매물명'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _reviewPrice,
          keyboardType: TextInputType.number,
          decoration: _field('가격', hint: '중고 판매가 (선택)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _reviewBody,
          minLines: 4,
          maxLines: 8,
          decoration: _field('본문', minLines: 4),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _pickPhoto(
            onPicked: (b) => setState(() => _reviewPhoto = b),
          ),
          icon: const Icon(Icons.photo_outlined),
          label: Text(_reviewPhoto == null ? '사진 첨부' : '사진 1장 선택됨'),
        ),
      ],
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.label,
    required this.onTap,
    this.bytes,
  });

  final String label;
  final Uint8List? bytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SoriTokens.border),
            image: bytes == null
                ? null
                : DecorationImage(image: MemoryImage(bytes!), fit: BoxFit.cover),
          ),
          child: bytes == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo_outlined, size: 28),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                )
              : Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Chip(
                      label: Text(label),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
