import 'dart:math';

import '../models/ai_reply.dart';
import '../models/customer_chart.dart';
import '../models/customer_review.dart';

/// 결제 테이블 연동 없이 visit_checked 처리 시
/// 고객용 토큰 발급 + 1:1 피드백 라인 개설을 담당한다.
class VisitTriggerService {
  VisitTriggerService({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  /// visit_checked = true 전환 시 즉시 토큰/피드백 라인 개설.
  CustomerChart markVisitChecked(CustomerChart chart) {
    if (chart.visitChecked && chart.hasFeedbackLine) {
      return chart;
    }

    final now = DateTime.now();
    return chart.copyWith(
      visitChecked: true,
      visitCheckedAt: chart.visitCheckedAt ?? now,
      feedbackToken: chart.feedbackToken ?? _generateToken(),
      feedbackLineOpenedAt: chart.feedbackLineOpenedAt ?? now,
    );
  }

  /// 피드백 라인 개설 직후 퍼즐 기반 초안 후기를 생성한다.
  CustomerReview createDraftReview({
    required CustomerChart chart,
    required List<String> puzzleSelections,
    required String customerName,
    required String treatmentType,
  }) {
    final puzzleText = puzzleSelections.isEmpty
        ? '시술 결과가 만족스러웠어요'
        : puzzleSelections.join(', ');
    final originalText =
        '$customerName님, $treatmentType 시술 후 느낌이 좋았습니다. '
        '특히 $puzzleText 부분이 마음에 들어요. '
        '다음에도 믿고 방문하고 싶습니다.';

    return CustomerReview(
      id: 'review-${chart.id}-${nowMillis()}',
      chartId: chart.id,
      customerId: chart.customerId,
      shopId: chart.shopId,
      puzzleSelections: puzzleSelections,
      originalText: originalText,
      status: ReviewStatus.draft,
    );
  }

  /// 답글 피드백 요청 시 비동기 AI 답글 레코드를 pending으로 생성.
  AiReply enqueueAiReply({
    required CustomerReview review,
  }) {
    return AiReply(
      id: 'ai-${review.id}-${nowMillis()}',
      reviewId: review.id,
      chartId: review.chartId,
      status: AiReplyStatus.pending,
    );
  }

  /// 비동기 생성 시뮬레이션 (호출측에서 Future.delayed 후 적용).
  AiReply completeAiReply(AiReply reply, {required String customerName}) {
    return reply.copyWith(
      status: AiReplyStatus.ready,
      replyText:
          '$customerName님, 소중한 후기 남겨 주셔서 감사합니다. '
          '시술 후 만족감을 느끼셨다니 원장으로서 큰 보람입니다. '
          '다음 방문 때도 컨디션에 맞는 케어로 모시겠습니다.',
      generatedAt: DateTime.now(),
    );
  }

  AiReply markCopied(AiReply reply) {
    return reply.copyWith(
      isCopied: true,
      copiedAt: DateTime.now(),
    );
  }

  String _generateToken() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static int nowMillis() => DateTime.now().millisecondsSinceEpoch;
}
