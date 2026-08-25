import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';
import '../views/my_app.dart';

/// 고객 심리 동선 표준 버튼: 후기 수락 / 수정 / 답글 피드백 요청
class PsychologyActionButtons extends StatelessWidget {
  const PsychologyActionButtons({
    super.key,
    required this.onAccept,
    required this.onEdit,
    required this.onRequestReply,
    this.acceptEnabled = true,
    this.editEnabled = true,
    this.requestReplyEnabled = true,
  });

  final VoidCallback? onAccept;
  final VoidCallback? onEdit;
  final VoidCallback? onRequestReply;
  final bool acceptEnabled;
  final bool editEnabled;
  final bool requestReplyEnabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: acceptEnabled ? onAccept : null,
          style: FilledButton.styleFrom(
            backgroundColor: MyApp.soriPurple,
            foregroundColor: SoriTokens.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            '후기 수락하기',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: editEnabled ? onEdit : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: MyApp.soriPurple,
            side: const BorderSide(color: MyApp.soriPurple),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            '수정하기',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: requestReplyEnabled ? onRequestReply : null,
          style: TextButton.styleFrom(
            foregroundColor: MyApp.soriPurple,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text(
            '답글 피드백 요청',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// 첫 방문 → 네이버 등록 / 회원권 N회차 → 복사·공유
class DynamicReviewMainAction extends StatelessWidget {
  const DynamicReviewMainAction({
    super.key,
    required this.isFirstVisit,
    required this.onNaverRegister,
    required this.onCopy,
    required this.onShare,
  });

  final bool isFirstVisit;
  final VoidCallback onNaverRegister;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    if (isFirstVisit) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onNaverRegister,
          icon: const Icon(Icons.storefront_outlined),
          label: const Text(
            '네이버에 등록하기',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF03C75A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('복사하기'),
            style: OutlinedButton.styleFrom(
              foregroundColor: MyApp.soriPurple,
              side: const BorderSide(color: MyApp.soriPurple),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('공유하기'),
            style: FilledButton.styleFrom(
              backgroundColor: MyApp.soriPurple,
              foregroundColor: SoriTokens.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
