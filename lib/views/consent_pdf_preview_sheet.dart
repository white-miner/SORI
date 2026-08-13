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

/// 앱 내부 동의서 PDF 미리보기 + 저장/인쇄 모달.
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
  Uint8List? _bytes;
  String? _error;
  var _loading = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
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

  static String _safeFileToken(String raw, {required String fallback}) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), '');
    return cleaned.isEmpty ? fallback : cleaned;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await _resolvePdfBytes();
      if (!mounted) return;
      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _loading = false;
          _error = '동의서 PDF를 불러오지 못했습니다.';
        });
        return;
      }
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'PDF 로드 실패: $e';
      });
    }
  }

  Future<Uint8List?> _resolvePdfBytes() async {
    final url = widget.chart.consentPdfUrl?.trim() ?? '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      try {
        final res = await http.get(Uri.parse(url));
        if (res.statusCode >= 200 &&
            res.statusCode < 300 &&
            res.bodyBytes.isNotEmpty) {
          return res.bodyBytes;
        }
      } catch (_) {
        // fall through to regenerate
      }
    }

    final careFallback = () {
      final t = widget.customer.treatmentType.trim();
      if (t.isNotEmpty) return t;
      final m = widget.customer.primaryMembership?.serviceName.trim() ?? '';
      if (m.isNotEmpty) return m;
      return null;
    }();

    return ConsentPdfGenerator.buildBytes(
      shopName: widget.store.shop.name,
      customerName: widget.customer.name,
      customerPhone: widget.customer.phone,
      chart: widget.chart,
      signatureUrl: widget.chart.signatureUrl,
      shopOwnerName: widget.store.shop.ownerName,
      careMenuName: careFallback,
    );
  }

  Future<void> _savePdf() async {
    final bytes = _bytes;
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
    final bytes = _bytes;
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

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: maxW,
        height: maxH,
        child: Column(
          children: [
            Padding(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: (_bytes == null || _busy) ? null : _savePdf,
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
                    onPressed: (_bytes == null || _busy) ? null : _printPdf,
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
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _load,
                                  child: const Text('다시 시도'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : PdfPreview(
                          build: (format) async => _bytes!,
                          pdfFileName: _fileName,
                          allowPrinting: false,
                          allowSharing: false,
                          canChangePageFormat: false,
                          canChangeOrientation: false,
                          canDebug: false,
                          useActions: false,
                          padding: EdgeInsets.zero,
                          previewPageMargin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
