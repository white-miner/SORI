import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../services/chart_photo_compressor.dart';
import '../services/chart_photo_storage.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/before_after_slider.dart';
import '../widgets/media_permission_dialogs.dart';
import 'admin_chart_writer_page.dart';
import 'my_app.dart';

/// 고객 상세 → 차트 관리: 회차 리스트 다이렉트 진입 + B/A·메타 상세.
class ChartManagementPage extends StatefulWidget {
  const ChartManagementPage({
    super.key,
    required this.store,
    required this.customerId,
    this.initialChartId,
  });

  final SoriStore store;
  final String customerId;
  final String? initialChartId;

  @override
  State<ChartManagementPage> createState() => _ChartManagementPageState();
}

class _ChartManagementPageState extends State<ChartManagementPage> {
  String? _selectedChartId;
  bool _showingDetail = false;
  bool _editing = false;
  bool _saving = false;
  bool _patchingAfter = false;

  late final TextEditingController _careCtrl;
  late final TextEditingController _summaryCtrl;
  late final TextEditingController _insightCtrl;

  @override
  void initState() {
    super.initState();
    _careCtrl = TextEditingController();
    _summaryCtrl = TextEditingController();
    _insightCtrl = TextEditingController();
    widget.store.addListener(_onStore);
    final charts = _timeline;
    final initial = widget.initialChartId?.trim();
    if (initial != null &&
        initial.isNotEmpty &&
        charts.any((c) => c.id == initial)) {
      _selectedChartId = initial;
      _showingDetail = true;
    } else {
      _showingDetail = false;
      _selectedChartId = null;
    }
    _syncEditorsFromSelected();
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    _careCtrl.dispose();
    _summaryCtrl.dispose();
    _insightCtrl.dispose();
    super.dispose();
  }

  void _onStore() {
    if (!mounted) return;
    final charts = _timeline;
    if (charts.isEmpty) {
      setState(() {
        _selectedChartId = null;
        _showingDetail = false;
        _editing = false;
      });
      return;
    }
    if (_showingDetail &&
        (_selectedChartId == null ||
            !charts.any((c) => c.id == _selectedChartId))) {
      setState(() {
        _selectedChartId = charts.first.id;
        _editing = false;
      });
      _syncEditorsFromSelected();
      return;
    }
    setState(() {});
    if (!_editing) _syncEditorsFromSelected();
  }

  Customer? get _customer =>
      widget.store.findCustomer(widget.customerId);

  List<CustomerChart> get _timeline =>
      widget.store.chartsForCustomer(widget.customerId);

  CustomerChart? get _selected {
    final id = _selectedChartId;
    if (id == null) return null;
    try {
      return _timeline.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  void _syncEditorsFromSelected() {
    final chart = _selected;
    _careCtrl.text = chart?.careName ?? '';
    _summaryCtrl.text = chart?.treatmentSummary ?? '';
    _insightCtrl.text = chart?.directorInsight ?? '';
  }

  void _openVisitDetail(String chartId) {
    setState(() {
      _selectedChartId = chartId;
      _showingDetail = true;
      _editing = false;
    });
    _syncEditorsFromSelected();
  }

  void _backToList() {
    setState(() {
      _showingDetail = false;
      _editing = false;
      _selectedChartId = null;
    });
  }

  Future<void> _saveEdits() async {
    final chart = _selected;
    if (chart == null || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.store.updateCustomerChartFields(
        chartId: chart.id,
        careName: _careCtrl.text,
        treatmentSummary: _summaryCtrl.text,
        directorInsight: _insightCtrl.text,
      );
      if (!mounted) return;
      setState(() => _editing = false);
      MyApp.scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('차트가 저장되었습니다'),
          backgroundColor: SoriTokens.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 실패: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _replacePhoto({required bool isBefore}) async {
    final chart = _selected;
    if (chart == null) return;
    final file = await pickImageWithPermissionGuards(
      context: context,
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null || !mounted) return;

    final raw = await file.readAsBytes();
    if (raw.isEmpty || !mounted) return;
    final compressed = await ChartPhotoCompressor.toWebp(raw);
    if (compressed == null || compressed.isEmpty || !mounted) return;

    setState(() => _saving = true);
    try {
      final url = await ChartPhotoStorage.uploadWebp(
        bytes: compressed,
        shopId: widget.store.shop.id,
        customerId: widget.customerId,
        kind: isBefore ? 'before' : 'after',
      );
      if (url == null || url.trim().isEmpty) {
        throw StateError('업로드 URL이 비어 있습니다');
      }
      await widget.store.updateCustomerChartFields(
        chartId: chart.id,
        beforeImageUrl: isBefore ? url : null,
        afterImageUrl: isBefore ? null : url,
      );
      if (!mounted) return;
      MyApp.scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(isBefore ? 'Before 사진을 교체했어요' : 'After 사진을 등록했어요'),
          backgroundColor: SoriTokens.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('사진 저장 실패: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _patchAfterOnly() async {
    final chart = _selected;
    if (chart == null || _patchingAfter) return;
    setState(() => _patchingAfter = true);
    try {
      final file = await pickImageWithPermissionGuards(
        context: context,
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file == null || !mounted) return;
      final raw = await file.readAsBytes();
      if (raw.isEmpty) return;
      final compressed = await ChartPhotoCompressor.toWebp(raw);
      if (compressed == null || compressed.isEmpty) return;
      final url = await ChartPhotoStorage.uploadWebp(
        bytes: compressed,
        shopId: widget.store.shop.id,
        customerId: widget.customerId,
        kind: 'after',
      );
      if (url == null || url.trim().isEmpty) {
        throw StateError('업로드 실패');
      }
      await widget.store.patchChartAfterImage(
        chartId: chart.id,
        afterImageUrl: url,
      );
      if (!mounted) return;
      MyApp.scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('After 사진을 등록해 차트를 완료했어요'),
          backgroundColor: SoriTokens.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('After 등록 실패: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _patchingAfter = false);
    }
  }

  Future<void> _openFullEditor() async {
    final customer = _customer;
    final chart = _selected;
    if (customer == null || chart == null) return;
    await openChartWriterForCustomer(
      context,
      store: widget.store,
      customer: customer,
      existingChart: chart,
    );
    if (mounted) setState(() {});
  }

  String _dateLabel(CustomerChart chart) {
    final dt =
        chart.visitCheckedAt ?? chart.feedbackLineOpenedAt ?? chart.createdAt;
    if (dt == null) return '미정';
    return '${dt.month}/${dt.day}';
  }

  Widget _networkOrPlaceholder(String? url, {required String label}) {
    final u = url?.trim() ?? '';
    if (u.isEmpty) {
      return ColoredBox(
        color: SoriTokens.border,
        child: Center(
          child: Text(
            '$label 없음',
            style: const TextStyle(
              color: SoriTokens.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    if (u.startsWith('data:')) {
      return ColoredBox(
        color: SoriTokens.border,
        child: const Center(child: Icon(Icons.image_outlined)),
      );
    }
    return CachedNetworkImage(
      imageUrl: u,
      fit: BoxFit.cover,
      placeholder: (_, _) => const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      errorWidget: (_, _, _) => ColoredBox(
        color: SoriTokens.border,
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;
    final charts = _timeline;
    final selected = _selected;
    final name = customer?.name ?? '고객';

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: Text(
          _showingDetail && selected != null
              ? '$name · ${selected.visitNumber}회차'
              : '$name · 차트 관리',
        ),
        backgroundColor: SoriTokens.surface,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () {
            if (_showingDetail) {
              _backToList();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
      ),
      body: charts.isEmpty
          ? const Center(child: Text('작성된 차트가 없습니다'))
          : !_showingDetail
              ? _buildVisitList(charts)
              : selected == null
                  ? const Center(child: Text('차트를 선택해 주세요'))
                  : _buildDetailBody(selected),
    );
  }

  Widget _buildVisitList(List<CustomerChart> charts) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: charts.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Text(
            '회차를 선택하면 사진·기록이 바로 열립니다',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: SoriTokens.textSecondary,
            ),
          );
        }
        final chart = charts[index - 1];
        final care = chart.careName.trim().isNotEmpty
            ? chart.careName.trim()
            : (chart.treatmentSummary.trim().isNotEmpty
                ? chart.treatmentSummary.trim()
                : '시술 기록');
        return Material(
          color: SoriTokens.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openVisitDetail(chart.id),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SoriTokens.outlinePurple),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: SoriTokens.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${chart.visitNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: SoriTokens.primary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${chart.visitNumber}회차 · $care',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dateLabel(chart),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: SoriTokens.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (chart.needsAfterPhoto)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        'After 대기',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: SoriTokens.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailBody(CustomerChart selected) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFeedShareBar(selected),
              const SizedBox(height: 10),
              Expanded(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 7,
                            child: _buildMediaPane(selected),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: _buildMetaPane(selected, expand: true),
                          ),
                        ],
                      )
                    : ListView(
                        children: [
                          SizedBox(
                            height: 320,
                            child: _buildMediaPane(selected),
                          ),
                          const SizedBox(height: 12),
                          _buildMetaPane(selected, expand: false),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onFeedShareChanged(CustomerChart chart, bool value) {
    final ok = widget.store.setManagementCaseShared(chart.id, value);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('고객의 정보 활용 동의서 서명이 완료된 차트만 공유할 수 있습니다.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFE53935),
        ),
      );
    }
  }

  Widget _buildFeedShareBar(CustomerChart chart) {
    final shared = chart.caseShared && chart.isConsentSigned;
    final canShare = chart.isConsentSigned;
    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
        child: Row(
          children: [
            const Icon(
              Icons.public_rounded,
              size: 20,
              color: SoriTokens.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '피드 공유',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.textPrimary,
                    ),
                  ),
                  Text(
                    canShare
                        ? (shared
                            ? '커뮤니티 피드에 공개 중'
                            : '동의 완료 · 공유하면 피드에 노출됩니다')
                        : '동의서 서명 후 공유할 수 있습니다',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: shared,
              activeThumbColor: const Color(0xFF22C55E),
              onChanged: (v) => _onFeedShareChanged(chart, v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPane(CustomerChart chart) {
    final before = _networkOrPlaceholder(chart.beforeImageUrl, label: 'Before');
    final after = _networkOrPlaceholder(chart.afterImageUrl, label: 'After');
    final both = chart.hasBeforeImage && chart.hasAfterImage;

    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'Before / After',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const Spacer(),
                if (_editing) ...[
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => _replacePhoto(isBefore: true),
                    child: const Text('Before 교체'),
                  ),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => _replacePhoto(isBefore: false),
                    child: const Text('After 교체'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final h = c.maxHeight.isFinite ? c.maxHeight : 280.0;
                  if (both) {
                    return BeforeAfterSlider(
                      before: before,
                      after: after,
                      height: h,
                    );
                  }
                  return SizedBox(
                    height: h,
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: before,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: after,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (chart.needsAfterPhoto) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _patchingAfter ? null : _patchAfterOnly,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _patchingAfter
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_a_photo_outlined),
                label: Text(
                  _patchingAfter ? '등록 중…' : 'After 사진 등록',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetaPane(CustomerChart chart, {bool expand = true}) {
    final care = chart.careName.trim().isNotEmpty
        ? chart.careName
        : (chart.treatmentSummary.trim().isNotEmpty
            ? chart.treatmentSummary
            : '시술 기록');

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Text(
          '${chart.visitNumber}회차',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: SoriTokens.primary,
          ),
        ),
        const SizedBox(height: 4),
        if (_editing) ...[
          TextField(
            controller: _careCtrl,
            decoration: const InputDecoration(
              labelText: '시술명',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _summaryCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '테크닉 / 제품 / 요약',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _insightCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '고객 반응 · 인사이트',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ] else ...[
          Text(
            care,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            chart.treatmentSummary.trim().isEmpty
                ? '시술 요약 없음'
                : chart.treatmentSummary,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (chart.directorInsight.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '고객 반응 · ${chart.directorInsight}',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (chart.concernChips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: chart.concernChips
                  .map(
                    (t) => Chip(
                      label: Text(t, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: SoriTokens.primarySoft,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
        if (expand) const Spacer(),
        if (!expand) const SizedBox(height: 16),
        if (_editing) ...[
          FilledButton(
            onPressed: _saving ? null : _saveEdits,
            style: FilledButton.styleFrom(
              backgroundColor: SoriTokens.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              _saving ? '저장 중…' : '저장하기',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _saving
                ? null
                : () {
                    setState(() => _editing = false);
                    _syncEditorsFromSelected();
                  },
            child: const Text('취소'),
          ),
        ] else ...[
          FilledButton.icon(
            onPressed: () => setState(() => _editing = true),
            style: FilledButton.styleFrom(
              backgroundColor: SoriTokens.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text(
              '수정하기',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _openFullEditor,
            child: const Text('전체 차트 작성기로 열기'),
          ),
        ],
      ],
    );

    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: body,
      ),
    );
  }
}
