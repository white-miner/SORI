import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/chart_consent_texts.dart';
import '../models/customer_chart.dart';

/// 전자 동의서 A4 PDF 생성기 — 서명 PNG를 픽셀로 임베드.
abstract final class ConsentPdfGenerator {
  /// [signaturePng]가 최우선. 없으면 URL / data-URL에서 복원.
  static Future<Uint8List> buildBytes({
    required String shopName,
    required String customerName,
    required String customerPhone,
    required CustomerChart chart,
    Uint8List? signaturePng,
    String? signatureUrl,
    String? shopOwnerName,
    String? careMenuName,
  }) async {
    final bytes = await resolveSignatureBytes(
      signaturePng: signaturePng,
      signatureUrl: signatureUrl ?? chart.signatureUrl,
    );

    final base = await PdfGoogleFonts.nanumGothicRegular();
    final bold = await PdfGoogleFonts.nanumGothicBold();
    final theme = pw.ThemeData.withFont(base: base, bold: bold);

    final doc = pw.Document(theme: theme);
    final sigImage =
        bytes != null && bytes.isNotEmpty ? pw.MemoryImage(bytes) : null;

    final signedAt = chart.createdAt ?? DateTime.now();
    final dateLabel =
        '${signedAt.year}.${signedAt.month.toString().padLeft(2, '0')}.${signedAt.day.toString().padLeft(2, '0')}';
    final owner = (shopOwnerName ?? '').trim().isEmpty
        ? shopName
        : shopOwnerName!.trim();
    final careLabel = resolveCareMenuName(
      chartCareName: chart.careName,
      fallbackCareName: careMenuName,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 44, 48, 48),
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
            ChartConsentTexts.documentTitle,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '고객: $customerName  ·  연락처: $customerPhone\n'
            '회차: ${chart.displayChartNo}  ·  관리: $careLabel\n'
            '작성일: $dateLabel',
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
          ),
          pw.SizedBox(height: 14),
          _section(
            ChartConsentTexts.mandatoryCareTitle,
            ChartConsentTexts.mandatoryCareBody,
            agreed: chart.consentMandatory,
          ),
          _section(
            ChartConsentTexts.mandatoryReactionTitle,
            ChartConsentTexts.mandatoryReactionBody,
            agreed: chart.consentMandatory,
          ),
          _section(
            ChartConsentTexts.mandatoryRefundTitle,
            ChartConsentTexts.mandatoryRefundBody,
            agreed: chart.consentMandatory,
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            '[촬영 동의] ${ChartConsentTexts.optionalPhotoTitle}',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 14),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _agreeLine('촬영 동의', chart.consentPhoto),
                if (chart.consentPhoto) ...[
                  pw.SizedBox(height: 8),
                  pw.Text(
                    _photoScopeLine(chart),
                    style: const pw.TextStyle(fontSize: 10, lineSpacing: 2.2),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 22),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _partyBlock(
                  title: '고객 서명',
                  nameLabel: '성명',
                  nameValue: customerName,
                  dateLabel: '작성일',
                  dateValue: dateLabel,
                  body: pw.Container(
                    height: 88,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.all(6),
                    child: sigImage != null
                        ? pw.Image(sigImage, fit: pw.BoxFit.contain)
                        : pw.Text(
                            '(서명 이미지 없음)',
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey600,
                            ),
                          ),
                  ),
                ),
              ),
              pw.SizedBox(width: 18),
              pw.Expanded(
                child: _partyBlock(
                  title: shopName,
                  nameLabel: '대표자',
                  nameValue: owner,
                  dateLabel: '확인일',
                  dateValue: dateLabel,
                  body: pw.Center(child: _shopSeal(shopName)),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            '본 문서는 SORI ${ChartConsentTexts.documentTitle} 자동 생성본이며, 원본 서명 픽셀을 포함합니다.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    return doc.save();
  }

  /// 차트 careName이 플레이스홀더면 고객 관리 메뉴명으로 대체.
  static String resolveCareMenuName({
    required String chartCareName,
    String? fallbackCareName,
  }) {
    final raw = chartCareName.trim();
    if (raw.isNotEmpty && !_isPlaceholderCareName(raw)) return raw;
    final fb = fallbackCareName?.trim() ?? '';
    if (fb.isNotEmpty && !_isPlaceholderCareName(fb)) return fb;
    return '-';
  }

  static bool _isPlaceholderCareName(String value) {
    final v = value.trim();
    return v.isEmpty ||
        v == '전자 동의서' ||
        v == '퀵 전자 동의서' ||
        v == '동의서';
  }

  static String _photoScopeLine(CustomerChart chart) {
    // 마케팅이 우선(둘 다 true인 레거시 데이터 대비), 아니면 원내 전용.
    if (chart.consentMarketing) {
      return ChartConsentTexts.photoScopeMarketing;
    }
    if (chart.consentOfflineOnly) {
      return ChartConsentTexts.photoScopeOffline;
    }
    // 촬영만 동의하고 범위 미선택 → 원내 기본
    return ChartConsentTexts.photoScopeOffline;
  }

  /// PNG 바이트 / data-URL / http(s) URL 순으로 서명 이미지 복원.
  static Future<Uint8List?> resolveSignatureBytes({
    Uint8List? signaturePng,
    String? signatureUrl,
  }) async {
    if (signaturePng != null && signaturePng.isNotEmpty) {
      return signaturePng;
    }
    final raw = signatureUrl?.trim() ?? '';
    if (raw.isEmpty) return null;

    final fromData = decodeDataUrl(raw);
    if (fromData != null && fromData.isNotEmpty) return fromData;

    if (raw.startsWith('local-signature-')) return null;

    return _downloadBytes(raw);
  }

  static Uint8List? decodeDataUrl(String value) {
    final v = value.trim();
    if (!v.startsWith('data:')) return null;
    final comma = v.indexOf(',');
    if (comma < 0 || comma >= v.length - 1) return null;
    final meta = v.substring(0, comma).toLowerCase();
    final payload = v.substring(comma + 1);
    try {
      if (meta.contains(';base64')) {
        return Uint8List.fromList(base64Decode(payload));
      }
      return Uint8List.fromList(utf8.encode(Uri.decodeComponent(payload)));
    } catch (_) {
      return null;
    }
  }

  /// 유니코드 체크박스(☑/☐)는 한글 폰트에서 글리프 누락 → ASCII 표기.
  static String _agreeMark(bool agreed) =>
      agreed ? '[V 동의]' : '[X 미동의]';

  static pw.Widget _section(
    String title,
    List<String> body, {
    required bool agreed,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              _agreeMark(agreed),
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: agreed ? PdfColors.green800 : PdfColors.grey600,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        ...body.map(
          (line) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3, left: 4),
            child: pw.Text(
              '- $line',
              style: const pw.TextStyle(fontSize: 9, lineSpacing: 2.5),
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _agreeLine(String title, bool agreed) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Text(
        '${_agreeMark(agreed)}  $title',
        style: const pw.TextStyle(fontSize: 10, lineSpacing: 2.2),
      ),
    );
  }

  static pw.Widget _partyBlock({
    required String title,
    required String nameLabel,
    required String nameValue,
    required String dateLabel,
    required String dateValue,
    required pw.Widget body,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          '$nameLabel: $nameValue',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 6),
        body,
        pw.SizedBox(height: 6),
        pw.Text(
          '$dateLabel: $dateValue',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  /// 샵 직인(도장) — 원형 스탬프 스타일.
  static pw.Widget _shopSeal(String shopName) {
    final label = _sealLabel(shopName);
    return pw.Container(
      width: 86,
      height: 86,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: PdfColors.red700, width: 2.2),
      ),
      child: pw.Container(
        width: 74,
        height: 74,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          shape: pw.BoxShape.circle,
          border: pw.Border.all(color: PdfColors.red400, width: 0.8),
        ),
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          label,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: label.length > 6 ? 8.5 : 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.red700,
            lineSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  static String _sealLabel(String shopName) {
    final t = shopName.trim();
    if (t.isEmpty) return '확인\n직인';
    if (t.length <= 4) return '$t\n직인';
    if (t.length <= 8) {
      final mid = (t.length / 2).ceil();
      return '${t.substring(0, mid)}\n${t.substring(mid)}';
    }
    return '${t.substring(0, 8)}\n직인';
  }

  static Future<Uint8List?> _downloadBytes(String? url) async {
    final u = url?.trim() ?? '';
    if (u.isEmpty) return null;
    if (!(u.startsWith('http://') || u.startsWith('https://'))) return null;
    try {
      final res = await http.get(Uri.parse(u));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final bytes = res.bodyBytes;
        if (bytes.isNotEmpty) return bytes;
      }
    } catch (_) {}
    return null;
  }
}
