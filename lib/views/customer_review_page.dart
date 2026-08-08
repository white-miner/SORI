import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ai_reply.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../models/customer_review.dart';
import '../services/sori_store.dart';
import '../widgets/psychology_action_buttons.dart';
import 'my_app.dart';

/// 고객용 독립 모바일 웹 (`/review?token=...`).
/// 원장 어드민 메뉴(고객 목록·전체 발송 등)는 절대 노출하지 않는다.
class CustomerReviewPage extends StatefulWidget {
  const CustomerReviewPage({
    super.key,
    required this.store,
    required this.token,
  });

  final SoriStore store;
  final String token;

  @override
  State<CustomerReviewPage> createState() => _CustomerReviewPageState();
}

class _CustomerReviewPageState extends State<CustomerReviewPage> {
  bool _generatingReply = false;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  CustomerChart? get _chart => widget.store.findChartByToken(widget.token);

  Customer? get _customer {
    final chart = _chart;
    if (chart == null) return null;
    return widget.store.findCustomer(chart.customerId);
  }

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
    widget.store.startEditingReview(review.id);
  }

  void _finishEdit() {
    final review = _review;
    if (review == null) return;
    widget.store.finishPuzzleEdit(review.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('퍼즐 문장으로 후기를 구성했습니다.'),
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
        content: Text('원장님께 답글 작성 과제를 전달했습니다.'),
        backgroundColor: MyApp.soriPurple,
      ),
    );
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('복사되었습니다.'),
        backgroundColor: MyApp.soriPurple,
      ),
    );
  }

  Future<void> _shareText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('공유용 문구를 복사했습니다. SNS에 붙여넣기 하세요.'),
        backgroundColor: MyApp.soriPurple,
      ),
    );
  }

  void _openNaver() {
    final url = widget.store.shop.naverPlaceUrl ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          url.isEmpty ? '네이버 플레이스 링크가 없습니다.' : '네이버 등록으로 이동: $url',
        ),
        backgroundColor: const Color(0xFF03C75A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chart = _chart;
    final customer = _customer;

    if (widget.token.trim().isEmpty || chart == null || customer == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F7FC),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link_off, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    '유효하지 않은 고객 링크입니다',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '원장님께 받은 QR 또는 문자 링크로 다시 접속해 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final review = _review;
    final aiReply = _aiReply;
    final isEditing = review?.status == ReviewStatus.editing;
    final showMainCta = review != null &&
        (review.status == ReviewStatus.accepted ||
            review.status == ReviewStatus.replyRequested ||
            review.status == ReviewStatus.published);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          children: [
            _CustomerBrandHeader(shopName: widget.store.shop.name),
            const SizedBox(height: 20),
            _DiagnosisReportCard(
              customerName: customer.name,
              chart: chart,
            ),
            if (review != null) ...[
              const SizedBox(height: 20),
              const Text(
                '나의 후기',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436),
                ),
              ),
              const SizedBox(height: 10),
              _CustomerReviewBody(
                review: review,
                isEditing: isEditing,
                onTogglePuzzle: (sentence) {
                  widget.store.togglePuzzleSentence(
                    reviewId: review.id,
                    sentence: sentence,
                  );
                },
                onFinishEdit: _finishEdit,
              ),
              const SizedBox(height: 16),
              PsychologyActionButtons(
                onAccept: _acceptReview,
                onEdit: _startEdit,
                onRequestReply: _generatingReply ? null : _requestReply,
                acceptEnabled: review.status != ReviewStatus.accepted &&
                    review.status != ReviewStatus.published &&
                    !isEditing,
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
                  aiReply.status == AiReplyStatus.ready) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MyApp.soriPurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '원장님께 답글 피드백 요청이 전달되었습니다. 곧 매장에서 답글을 확인해 주세요.',
                    style: TextStyle(
                      color: MyApp.soriPurple,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              if (showMainCta) ...[
                const SizedBox(height: 20),
                Text(
                  chart.isFirstVisit
                      ? '첫 방문이시라면 네이버에 남겨 주세요'
                      : '회원권 ${chart.visitNumber}회차 · 후기를 공유해 주세요',
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
      ),
    );
  }
}

class _CustomerBrandHeader extends StatelessWidget {
  const _CustomerBrandHeader({required this.shopName});

  final String shopName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: MyApp.soriPurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'SORI',
            style: TextStyle(
              color: MyApp.soriPurple,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          shopName,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3436),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '오늘의 시술 리포트를 확인하고 후기를 남겨 주세요',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _DiagnosisReportCard extends StatelessWidget {
  const _DiagnosisReportCard({
    required this.customerName,
    required this.chart,
  });

  final String customerName;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$customerName님 진단 리포트',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${chart.visitNumber}회차 · ${chart.treatmentSummary}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniBox(label: 'Before'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniBox(label: 'After'),
              ),
            ],
          ),
          if (chart.directorInsight.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F1FB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '원장 인사이트\n${chart.directorInsight}',
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniBox extends StatelessWidget {
  const _MiniBox({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F1FB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: MyApp.soriPurple,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CustomerReviewBody extends StatelessWidget {
  const _CustomerReviewBody({
    required this.review,
    required this.isEditing,
    required this.onTogglePuzzle,
    required this.onFinishEdit,
  });

  final CustomerReview review;
  final bool isEditing;
  final ValueChanged<String> onTogglePuzzle;
  final VoidCallback onFinishEdit;

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
          Text(
            review.displayText,
            style: const TextStyle(height: 1.5, fontSize: 14),
          ),
          if (isEditing) ...[
            const SizedBox(height: 14),
            Text(
              '퍼즐 문장 켜고 끄기',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SoriStore.puzzlePool.map((sentence) {
                final selected = review.puzzleSelections.contains(sentence);
                return FilterChip(
                  label: Text(sentence, style: const TextStyle(fontSize: 12)),
                  selected: selected,
                  onSelected: (_) => onTogglePuzzle(sentence),
                  selectedColor: MyApp.soriPurple.withValues(alpha: 0.18),
                  checkmarkColor: MyApp.soriPurple,
                  labelStyle: TextStyle(
                    color: selected ? MyApp.soriPurple : Colors.grey.shade800,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: onFinishEdit,
                style: FilledButton.styleFrom(
                  backgroundColor: MyApp.soriPurple,
                ),
                child: const Text('수정 완료'),
              ),
            ),
          ] else if (review.puzzleSelections.isNotEmpty) ...[
            const SizedBox(height: 12),
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
          ],
        ],
      ),
    );
  }
}
