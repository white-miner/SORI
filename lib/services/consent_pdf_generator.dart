import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/chart_consent_texts.dart';
import '../models/customer_chart.dart';

/// 전자 동의서 A4 PDF 생성기 — 서명 PNG를 픽셀로 임베드.
abstract final class ConsentPdfGenerator {
  /// [signaturePng]가 없으면 [signatureUrl]에서 다운로드 시도.
  static Future<Uint8List> buildBytes({
    required String shopName,
    required String customerName,
    required String customerPhone,
    required CustomerChart chart,
    Uint8List? signaturePng,
    String? signatureUrl,
  }) async {
    final bytes = signaturePng ??
        await _downloadBytes(signatureUrl ?? chart.signatureUrl);

    final base = await PdfGoogleFonts.nanumGothicRegular();
    final bold = await PdfGoogleFonts.nanumGothicBold();
    final theme = pw.ThemeData.withFont(base: base, bold: bold);

    final doc = pw.Document(theme: theme);
    final sigImage = bytes != null && bytes.isNotEmpty
        ? pw.MemoryImage(bytes)
        : null;

    final signedAt = chart.createdAt ?? DateTime.now();
    final dateLabel =
        '${signedAt.year}.${signedAt.month.toString().padLeft(2, '0')}.${signedAt.day.toString().padLeft(2, '0')}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 48),
        build: (context) => [
          pw.Text(
            shopName,
            style: pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey700,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '케어 전자 동의서',
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '고객: $customerName  ·  연락처: $customerPhone\n'
            '회차: ${chart.displayChartNo}  ·  케어: ${chart.careName.isEmpty ? '-' : chart.careName}\n'
            '작성일: $dateLabel',
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            ChartConsentTexts.intro,
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
          ),
          pw.SizedBox(height: 14),
          _section(
            ChartConsentTexts.mandatoryCareTitle,
            ChartConsentTexts.mandatoryCareBody,
            checked: chart.consentMandatory,
          ),
          _section(
            ChartConsentTexts.mandatoryReactionTitle,
            ChartConsentTexts.mandatoryReactionBody,
            checked: chart.consentMandatory,
          ),
          _section(
            ChartConsentTexts.mandatoryRefundTitle,
            ChartConsentTexts.mandatoryRefundBody,
            checked: chart.consentMandatory,
          ),
          if (chart.consentPhoto) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              ChartConsentTexts.optionalPhotoTitle,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            if (chart.consentMarketing)
              pw.Text(
                '☑ ${ChartConsentTexts.photoUseMarketing}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            if (chart.consentOfflineOnly)
              pw.Text(
                '☑ ${ChartConsentTexts.photoUseOffline}',
                style: const pw.TextStyle(fontSize: 10),
              ),
          ],
          pw.SizedBox(height: 24),
          pw.Text(
            '고객 서명',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            width: 220,
            height: 90,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            alignment: pw.Alignment.center,
            child: sigImage != null
                ? pw.Image(sigImage, fit: pw.BoxFit.contain)
                : pw.Text(
                    '(서명 이미지 없음)',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            '본 문서는 SORI 전자 동의서 자동 생성본이며, 원본 서명 픽셀을 포함합니다.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _section(
    String title,
    List<String> body, {
    required bool checked,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 10),
        pw.Text(
          '${checked ? '☑' : '☐'} $title',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        ...body.map(
          (line) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              '· $line',
              style: const pw.TextStyle(fontSize: 9, lineSpacing: 2.5),
            ),
          ),
        ),
      ],
    );
  }

  static Future<Uint8List?> _downloadBytes(String? url) async {
    final u = url?.trim() ?? '';
    if (u.isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(u));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return res.bodyBytes;
      }
    } catch (_) {}
    return null;
  }
}
