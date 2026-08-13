import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../models/chart_consent_texts.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../services/consent_pdf_generator.dart';
import '../services/sori_store.dart';

/// 앱 내부 동의서 미리보기 + PDF 저장/인쇄 모달.
/// 미리보기는 PDF.js 없이 Flutter 정적 문서로 즉시 표시한다.
Future<void> showConsentPdfPreviewModal({
  required BuildContext context,
  required SoriStore store,
  required Customer customer,
  required CustomerChart chart,
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _ConsentPdfPreviewDialog(
      store: store,
      customer: customer,
      chart: chart,
    ),
  );
}

class _ConsentPdfPreviewDialog extends StatefulWidget {
  const _ConsentPdfPreviewDialog({
    required this.store,
    required this.customer,
    required this.chart,
  });

  final SoriStore store;
  final Customer customer;
  final CustomerChart chart;

  @override
  State<_ConsentPdfPreviewDialog> createState() =>
      _ConsentPdfPreviewDialogState();
}

class _ConsentPdfPreviewDialogState extends State<_ConsentPdfPreviewDialog> {
  Uint8List? _pdfBytes;
  String? _pdfError;
  var _preparingPdf = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_preparePdfBytes());
  }

  String get _fileName {
    final name = _safeFileToken(widget.customer.name, fallback: '고객');
    final dt = widget.chart.consentSignedAt ??
        widget.chart.createdAt ??
        DateTime.now();
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${name}_고객정보및관리동의서_$y$m$d.pdf';
  }

  String get _careLabel => ConsentPdfGenerator.resolveCareMenuName(
        chartCareName: widget.chart.careName,
        fallbackCareName: () {
          final t = widget.customer.treatmentType.trim();
          if (t.isNotEmpty) return t;
          final m =
              widget.customer.primaryMembership?.serviceName.trim() ?? '';
          if (m.isNotEmpty) return m;
          return null;
        }(),
      );

  String get _dateLabel {
    final dt = widget.chart.consentSignedAt ??
        widget.chart.createdAt ??
        DateTime.now();
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  static String _safeFileToken(String raw, {required String fallback}) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), '');
    return cleaned.isEmpty ? fallback : cleaned;
  }

  Future<void> _preparePdfBytes() async {
    setState(() {
      _preparingPdf = true;
      _pdfError = null;
    });
    try {
      final bytes = await _resolvePdfBytes().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('PDF 생성 시간 초과'),
      );
      if (!mounted) return;
      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _preparingPdf = false;
          _pdfError = '동의서 PDF를 준비하지 못했습니다.';
        });
        return;
      }
      setState(() {
        _pdfBytes = bytes;
        _preparingPdf = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _preparingPdf = false;
        _pdfError = 'PDF 준비 실패: $e';
      });
    }
  }

  Future<Uint8List?> _resolvePdfBytes() async {
    // 원격 URL은 CORS/지연으로 먹통이 되기 쉬워 짧게만 시도 후 즉시 재생성.
    final url = widget.chart.consentPdfUrl?.trim() ?? '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 2));
        if (res.statusCode >= 200 &&
            res.statusCode < 300 &&
            res.bodyBytes.isNotEmpty) {
          return res.bodyBytes;
        }
      } catch (_) {}
    }

    return ConsentPdfGenerator.buildBytes(
      shopName: widget.store.shop.name,
      customerName: widget.customer.name,
      customerPhone: widget.customer.phone,
      chart: widget.chart,
      signatureUrl: widget.chart.signatureUrl,
      shopOwnerName: widget.store.shop.ownerName,
      careMenuName: _careLabel == '-' ? null : _careLabel,
    );
  }

  Future<void> _savePdf() async {
    final bytes = _pdfBytes;
    if (bytes == null || bytes.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await Printing.sharePdf(bytes: bytes, filename: _fileName);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF 저장 실패: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printPdf() async {
    final bytes = _pdfBytes;
    if (bytes == null || bytes.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await Printing.layoutPdf(
        name: _fileName,
        onLayout: (PdfPageFormat format) async => bytes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('인쇄 실패: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxW = size.width >= 900 ? 820.0 : size.width * 0.96;
    final maxH = size.height * 0.92;
    final canAct = _pdfBytes != null && !_busy && !_preparingPdf;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      backgroundColor: const Color(0xFFF3F4F6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: maxW,
        height: maxH,
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      ChartConsentTexts.documentTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: canAct ? _savePdf : null,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('PDF 저장'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: canAct ? _printPdf : null,
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('바로 인쇄'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF111827),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  if (_preparingPdf)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'PDF 준비 중…',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else if (_pdfError != null)
                    TextButton(
                      onPressed: _preparePdfBytes,
                      child: const Text('PDF 다시 준비'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: _ConsentStaticDocument(
                        shopName: widget.store.shop.name,
                        shopOwnerName:
                            (widget.store.shop.ownerName ?? '').trim().isEmpty
                                ? widget.store.shop.name
                                : widget.store.shop.ownerName!.trim(),
                        customerName: widget.customer.name,
                        customerPhone: widget.customer.phone,
                        careLabel: _careLabel,
                        visitLabel: widget.chart.displayChartNo,
                        dateLabel: _dateLabel,
                        chart: widget.chart,
                      ),
                    ),
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

/// PDF.js 없는 고정 스크롤 미리보기 문서.
class _ConsentStaticDocument extends StatelessWidget {
  const _ConsentStaticDocument({
    required this.shopName,
    required this.shopOwnerName,
    required this.customerName,
    required this.customerPhone,
    required this.careLabel,
    required this.visitLabel,
    required this.dateLabel,
    required this.chart,
  });

  final String shopName;
  final String shopOwnerName;
  final String customerName;
  final String customerPhone;
  final String careLabel;
  final String visitLabel;
  final String dateLabel;
  final CustomerChart chart;

  String _mark(bool agreed) => agreed ? '[V 동의]' : '[X 미동의]';

  String get _photoScope {
    if (!chart.consentPhoto) return '';
    if (chart.consentMarketing) return ChartConsentTexts.photoScopeMarketing;
    return ChartConsentTexts.photoScopeOffline;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shopName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              ChartConsentTexts.documentTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '고객: $customerName  ·  연락처: $customerPhone\n'
              '회차: $visitLabel  ·  관리: $careLabel\n'
              '작성일: $dateLabel',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            _section(
              ChartConsentTexts.mandatoryCareTitle,
              ChartConsentTexts.mandatoryCareBody,
              chart.consentMandatory,
            ),
            _section(
              ChartConsentTexts.mandatoryReactionTitle,
              ChartConsentTexts.mandatoryReactionBody,
              chart.consentMandatory,
            ),
            _section(
              ChartConsentTexts.mandatoryRefundTitle,
              ChartConsentTexts.mandatoryRefundBody,
              chart.consentMandatory,
            ),
            const SizedBox(height: 14),
            Text(
              '[촬영 동의] ${ChartConsentTexts.optionalPhotoTitle}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_mark(chart.consentPhoto)}  촬영 동의',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (chart.consentPhoto) ...[
                    const SizedBox(height: 8),
                    Text(
                      _photoScope,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _partyColumn(
                    title: '고객 서명',
                    nameLabel: '성명',
                    nameValue: customerName,
                    dateLabel: '작성일',
                    dateValue: dateLabel,
                    child: _signatureBox(chart.signatureUrl),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _partyColumn(
                    title: shopName,
                    nameLabel: '대표자',
                    nameValue: shopOwnerName,
                    dateLabel: '확인일',
                    dateValue: dateLabel,
                    child: Center(child: _shopSeal(shopName)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '본 문서는 SORI ${ChartConsentTexts.documentTitle} 미리보기이며, '
              '저장/인쇄 시 PDF 원본이 사용됩니다.',
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<String> body, bool agreed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _mark(agreed),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: agreed
                      ? const Color(0xFF166534)
                      : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final line in body)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 2),
              child: Text(
                '- $line',
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: Color(0xFF374151),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _partyColumn({
    required String title,
    required String nameLabel,
    required String nameValue,
    required String dateLabel,
    required String dateValue,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '$nameLabel: $nameValue',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        child,
        const SizedBox(height: 8),
        Text(
          '$dateLabel: $dateValue',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _signatureBox(String? signatureUrl) {
    final url = signatureUrl?.trim() ?? '';
    final isHttp = url.startsWith('http://') || url.startsWith('https://');
    final isData = url.startsWith('data:image');
    return Container(
      height: 96,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD1D5DB)),
        borderRadius: BorderRadius.circular(6),
        color: const Color(0xFFFAFAFA),
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: isHttp
          ? Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text(
                '(서명 이미지 없음)',
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            )
          : isData
              ? Builder(
                  builder: (context) {
                    final bytes = _decodeDataUrl(url);
                    if (bytes == null || bytes.isEmpty) {
                      return const Text(
                        '(서명 이미지 없음)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      );
                    }
                    return Image.memory(bytes, fit: BoxFit.contain);
                  },
                )
              : const Text(
                  '(서명 이미지 없음)',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
    );
  }

  Widget _shopSeal(String shopName) {
    final t = shopName.trim();
    final label = t.isEmpty
        ? '확인\n직인'
        : (t.length <= 4
            ? '$t\n직인'
            : (t.length <= 8
                ? '${t.substring(0, (t.length / 2).ceil())}\n${t.substring((t.length / 2).ceil())}'
                : '${t.substring(0, 8)}\n직인'));
    return Container(
      width: 86,
      height: 86,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFB91C1C), width: 2.2),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFFB91C1C),
          height: 1.25,
        ),
      ),
    );
  }

  Uint8List? _decodeDataUrl(String value) {
    return ConsentPdfGenerator.decodeDataUrl(value);
  }
}
