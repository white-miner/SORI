import 'package:flutter/material.dart';

import '../models/customer_review.dart';
import '../theme/sori_tokens.dart';
import '../utils/pii_mask.dart';

/// B/A 케이스 카드용 — 고객 후기 + 원장 답글 인라인 스토리텔링.
class CaseReviewInlineBlock extends StatefulWidget {
  const CaseReviewInlineBlock({
    super.key,
    required this.review,
    this.compact = false,
    this.previewMaxLines = 3,
    this.anonymizeNames = true,
    this.expandInline = false,
  });

  final CustomerReview review;
  final bool compact;

  /// 공개 피드에서는 고객 실명을 마스킹한다.
  final bool anonymizeNames;

  /// 피드 미리보기 줄 수 (더 보기 / 팝업 연결).
  final int previewMaxLines;

  /// true면 시트 대신 카드 내 AnimatedSize 확장.
  final bool expandInline;

  @override
  State<CaseReviewInlineBlock> createState() => _CaseReviewInlineBlockState();
}

class _CaseReviewInlineBlockState extends State<CaseReviewInlineBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    var body = widget.review.displayText.trim();
    if (body.isEmpty) return const SizedBox.shrink();
    var reply = widget.review.directorReply?.trim();
    if (widget.anonymizeNames) {
      body = PiiMask.customerNames(body);
      if (reply != null && reply.isNotEmpty) {
        reply = PiiMask.customerNames(reply);
      }
    }
    final directorReply =
        (reply != null && reply.isNotEmpty) ? reply : null;
    final compact = widget.compact;
    final maxLines = widget.previewMaxLines.clamp(2, 6);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: compact ? 0 : 10),
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: SoriTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SoriTokens.outlinePurple),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💬 고객 후기',
            style: TextStyle(
              fontSize: compact ? 11.5 : 12,
              fontWeight: FontWeight.w800,
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: Text(
              body,
              maxLines: _expanded ? null : maxLines,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 12.5 : 13.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: SoriTokens.textPrimary,
              ),
            ),
          ),
          if (!_expanded && (body.length > 70 || widget.expandInline))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  if (widget.expandInline) {
                    setState(() => _expanded = true);
                    return;
                  }
                  _showFullReview(context, body, directorReply);
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: const Color(0xFF7DD3FC),
                ),
                child: const Text(
                  '더보기',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
            ),
          if (_expanded && widget.expandInline)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expanded = false),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: const Color(0xFF7DD3FC),
                ),
                child: const Text(
                  '접기',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
            ),
          if (directorReply != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  color: SoriTokens.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDDD6FE)),
                ),
                child: Text(
                  '↳ 👑 원장님: $directorReply',
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: SoriTokens.primary.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showFullReview(
    BuildContext context,
    String body,
    String? directorReply,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: SoriTokens.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const Text(
                '고객 후기',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.45,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    body,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (directorReply != null) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SoriTokens.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '↳ 👑 원장님: $directorReply',
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: SoriTokens.primary,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() => _expanded = true);
                    Navigator.pop(ctx);
                  },
                  child: const Text('인라인으로 펼치기'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 실제 후기 인증 뱃지.
class VerifiedReviewBadge extends StatelessWidget {
  const VerifiedReviewBadge({super.key, this.small = false});

  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 7 : 9,
        vertical: small ? 3 : 4,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8A95), Color(0xFFC44DFF)],
        ),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      child: Text(
        '실제 후기 인증',
        style: TextStyle(
          color: Colors.white,
          fontSize: small ? 10 : 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
