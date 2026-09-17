import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/kakao_alimtalk.dart';
import '../../../services/sori_store.dart';
import '../../../theme/sori_tokens.dart';
import '../../../views/kakao_alimtalk_actions.dart';
import '../report/visit_care_report.dart';
import '../report/visit_report_kakao_launcher.dart';

/// PRD v6.0 — post visit-end Kakao share sheet.
class VisitReportSendSheet extends StatelessWidget {
  const VisitReportSendSheet({
    super.key,
    required this.report,
    required this.customerPhone,
    required this.store,
  });

  final VisitCareReport report;
  final String customerPhone;
  final SoriStore store;

  static Future<void> show(
    BuildContext context, {
    required VisitCareReport report,
    required String customerPhone,
    required SoriStore store,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VisitReportSendSheet(
        report: report,
        customerPhone: customerPhone,
        store: store,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phoneReady = customerPhone.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: SoriTokens.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '방문이 종료되었습니다',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    report.kakaoLongMessage,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      height: 1.55,
                      fontWeight: FontWeight.w600,
                      color: SoriTokens.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: () async {
                    await VisitReportKakaoLauncher.sendViaKakao(
                      report.kakaoLongMessage,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          phoneReady
                              ? '문구를 복사했어요. 카카오톡에서 붙여넣어 보내주세요.'
                              : '문구를 복사했어요. 고객 연락처를 확인해 주세요.',
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(0xFF34C759),
                      ),
                    );
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.chat_bubble_rounded, size: 20),
                  label: const Text(
                    '카카오톡으로 보내기',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF34C759),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => copyKakaoMessage(
                  context,
                  report.kakaoLongMessage,
                ),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('문구 복사'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: report.publicReportUrl),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('리포트 링크를 복사했어요'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: SoriTokens.primary,
                    ),
                  );
                },
                icon: const Icon(Icons.link_rounded, size: 18),
                label: const Text('리포트 링크 복사'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: phoneReady
                    ? () async {
                        await sendKakaoAlimtalkWithUi(
                          context,
                          store: store,
                          customerPhone: customerPhone,
                          content: report.kakaoShortMessage,
                          templateCode: KakaoAlimtalkPricing.careReportTemplate,
                        );
                      }
                    : null,
                child: Text(
                  phoneReady
                      ? '알림톡 발송 (${KakaoAlimtalkPricing.sendCostPoint}P)'
                      : '알림톡 — 연락처 등록 필요',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: phoneReady
                        ? SoriTokens.textSecondary
                        : SoriTokens.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('나중에'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
