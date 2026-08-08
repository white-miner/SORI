import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ai_reply.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../models/customer_review.dart';
import '../services/sori_store.dart';
import '../widgets/psychology_action_buttons.dart';
import 'my_app.dart';

class CustomerDetailPage extends StatefulWidget {
  const CustomerDetailPage({
    super.key,
    required this.store,
    required this.customerId,
  });

  final SoriStore store;
  final String customerId;

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  late final TextEditingController _editController;
  bool _generatingReply = false;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    _editController.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Customer? get _customer => widget.store.findCustomer(widget.customerId);

  CustomerChart? get _chart => widget.store.latestChart(widget.customerId);

  CustomerReview? get _review {
    final chart = _chart;
    if (chart == null) return null;
    return widget.store.reviewForChart(chart.id);
  }

  AiReply? get _aiReply {
    final review = _review;
    if (review == null) return null;
    return widget.store.aiReplyForReview(review.id);
  }

  Future<void> _confirmVisit() async {
    final chart = _chart;
    if (chart == null) return;

    widget.store.confirmVisit(chartId: chart.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('방문 확인 완료 · 고객용 토큰 및 1:1 피드백 라인이 개설되었습니다.'),
        backgroundColor: MyApp.soriPurple,
      ),
    );
  }

  Future<void> _acceptReview() async {
    final review = _review;
    if (review == null) return;
    widget.store.acceptReview(review.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('후기를 수락했습니다.'),
        backgroundColor: MyApp.soriPurple,
      ),
    );
  }

  void _startEdit() {
    final review = _review;
    if (review == null) return;
    _editController.text = review.displayText;
    widget.store.startEditingReview(review.id);
  }

  void _saveEdit() {
    final review = _review;
    if (review == null) return;
    widget.store.saveEditedReview(review.id, _editController.text.trim());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('수정된 후기를 저장했습니다.'),
        backgroundColor: MyApp.soriPurple,
      ),
    );
  }

  Future<void> _requestReply() async {
    final review = _review;
    if (review == null) return;
    setState(() => _generatingReply = true);
    await widget.store.requestAiReplyFeedback(review.id);
    if (!mounted) return;
    setState(() => _generatingReply = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI 답글이 생성되었습니다.'),
        backgroundColor: MyApp.soriPurple,
      ),
    );
  }

  Future<void> _copyText(String text, {String? replyId}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (replyId != null) {
      widget.store.markAiReplyCopied(replyId);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('클립보드에 복사되었습니다.'),
        backgroundColor: MyApp.soriPurple,
      ),
    );
  }

  Future<void> _shareText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('공유용 문구를 복사했습니다. SNS·메시지에 붙여넣기 하세요.'),
        backgroundColor: MyApp.soriPurple,
      ),
    );
  }

  void _openNaver() {
    final url = widget.store.shop.naverPlaceUrl ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          url.isEmpty
              ? '네이버 플레이스 URL이 없습니다.'
              : '네이버 등록 링크 준비: $url',
        ),
        backgroundColor: const Color(0xFF03C75A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;
    final chart = _chart;

    if (customer == null || chart == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('고객 상세')),
        body: const Center(child: Text('고객 정보를 찾을 수 없습니다.')),
      );
    }

    final review = _review;
    final aiReply = _aiReply;
    final isEditing = review?.status == ReviewStatus.editing;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        title: Text(customer.name),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2D3436),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _CustomerSummaryCard(customer: customer, chart: chart),
          const SizedBox(height: 16),
          _ChartCard(
            chart: chart,
            onConfirmVisit: chart.visitChecked ? null : _confirmVisit,
          ),
          if (chart.hasFeedbackLine) ...[
            const SizedBox(height: 16),
            _FeedbackLineBanner(token: chart.feedbackToken!),
          ],
          if (review != null) ...[
            const SizedBox(height: 20),
            const Text(
              '고객 후기 피드백',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3436),
              ),
            ),
            const SizedBox(height: 10),
            _ReviewCard(
              review: review,
              isEditing: isEditing,
              editController: _editController,
              onSaveEdit: _saveEdit,
            ),
            const SizedBox(height: 16),
            PsychologyActionButtons(
              onAccept: _acceptReview,
              onEdit: _startEdit,
              onRequestReply: _generatingReply ? null : _requestReply,
              acceptEnabled: review.status != ReviewStatus.accepted &&
                  review.status != ReviewStatus.published,
              editEnabled: !isEditing,
              requestReplyEnabled: !_generatingReply,
            ),
            if (_generatingReply) ...[
              const SizedBox(height: 12),
              const Center(
                child: CircularProgressIndicator(color: MyApp.soriPurple),
              ),
            ],
            if (aiReply != null &&
                aiReply.status == AiReplyStatus.ready &&
                aiReply.replyText != null) ...[
              const SizedBox(height: 20),
              _AiReplyCard(
                reply: aiReply,
                onCopy: () => _copyText(
                  aiReply.replyText!,
                  replyId: aiReply.id,
                ),
              ),
            ],
            if (review.status == ReviewStatus.accepted ||
                review.status == ReviewStatus.replyRequested ||
                review.status == ReviewStatus.published) ...[
              const SizedBox(height: 20),
              Text(
                chart.isFirstVisit
                    ? '첫 방문 고객 · 네이버 리뷰 유도'
                    : '회원권 ${chart.visitNumber}회차 · 후기 공유',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 10),
              DynamicReviewMainAction(
                isFirstVisit: chart.isFirstVisit,
                onNaverRegister: _openNaver,
                onCopy: () => _copyText(review.displayText),
                onShare: () => _shareText(review.displayText),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CustomerSummaryCard extends StatelessWidget {
  const _CustomerSummaryCard({
    required this.customer,
    required this.chart,
  });

  final Customer customer;
  final CustomerChart chart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: MyApp.soriPurple.withValues(alpha: 0.12),
            child: Text(
              customer.name.characters.first,
              style: const TextStyle(
                color: MyApp.soriPurple,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  customer.phone,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  chart.isFirstVisit
                      ? '상태: 첫 방문'
                      : '상태: 회원권 ${chart.visitNumber}회차'
                          '${customer.membershipTotalVisits > 0 ? ' · 누적 ${customer.membershipTotalVisits}회' : ''}',
                  style: const TextStyle(
                    color: MyApp.soriPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.chart,
    required this.onConfirmVisit,
  });

  final CustomerChart chart;
  final VoidCallback? onConfirmVisit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '시술 차트',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: MyApp.soriPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${chart.visitNumber}회차',
                  style: const TextStyle(
                    color: MyApp.soriPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BeforeAfterBox(
                  label: 'Before',
                  hasImage: chart.beforeImageUrl != null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BeforeAfterBox(
                  label: 'After',
                  hasImage: chart.afterImageUrl != null,
                ),
              ),
            ],
          ),
          if (chart.treatmentSummary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              chart.treatmentSummary,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
          if (chart.directorInsight.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '원장 인사이트: ${chart.directorInsight}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onConfirmVisit,
              style: FilledButton.styleFrom(
                backgroundColor: chart.visitChecked
                    ? Colors.grey.shade400
                    : MyApp.soriPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                chart.visitChecked ? '방문 확인 완료' : '방문 확인 (visit_checked)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BeforeAfterBox extends StatelessWidget {
  const _BeforeAfterBox({
    required this.label,
    required this.hasImage,
  });

  final String label;
  final bool hasImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F1FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasImage ? Icons.image : Icons.image_outlined,
            color: MyApp.soriPurple.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackLineBanner extends StatelessWidget {
  const _FeedbackLineBanner({required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MyApp.soriPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MyApp.soriPurple.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1:1 피드백 라인 개설됨',
            style: TextStyle(
              color: MyApp.soriPurple,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '고객 토큰: ${token.substring(0, token.length.clamp(0, 12))}…',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.isEditing,
    required this.editController,
    required this.onSaveEdit,
  });

  final CustomerReview review;
  final bool isEditing;
  final TextEditingController editController;
  final VoidCallback onSaveEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (review.puzzleSelections.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: review.puzzleSelections
                  .map(
                    (s) => Chip(
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      backgroundColor:
                          MyApp.soriPurple.withValues(alpha: 0.08),
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (isEditing) ...[
            TextField(
              controller: editController,
              maxLines: 5,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                hintText: '후기 내용을 수정하세요',
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: onSaveEdit,
                style: FilledButton.styleFrom(
                  backgroundColor: MyApp.soriPurple,
                ),
                child: const Text('수정 저장'),
              ),
            ),
          ] else
            Text(
              review.displayText,
              style: const TextStyle(height: 1.5, fontSize: 14),
            ),
        ],
      ),
    );
  }
}

class _AiReplyCard extends StatelessWidget {
  const _AiReplyCard({
    required this.reply,
    required this.onCopy,
  });

  final AiReply reply;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'AI 답글',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              if (reply.isCopied)
                Text(
                  '복사됨',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            reply.replyText!,
            style: const TextStyle(height: 1.5, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('답글 복사'),
              style: TextButton.styleFrom(foregroundColor: MyApp.soriPurple),
            ),
          ),
        ],
      ),
    );
  }
}
