import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ai_reply.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../models/customer_review.dart';
import '../services/sori_store.dart';
import '../widgets/psychology_action_buttons.dart';
import 'my_app.dart';

/// 고객용 독립 모바일 웹 (`/#/review?token=...`). 어드민 셸 미렌더링.
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
  bool _verified = false;
  bool _verifyPromptShown = false;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVerified());
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

  Future<void> _ensureVerified() async {
    if (_verifyPromptShown || _verified) return;
    final customer = _customer;
    if (customer == null) return;
    _verifyPromptShown = true;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PhoneLast4Dialog(
        customerName: customer.name,
        onSubmit: (last4) => widget.store.verifyPhoneLast4(
          expectedPhone: customer.phone,
          inputLast4: last4,
        ),
      ),
    );

    if (!mounted) return;

    if (ok == true) {
      setState(() => _verified = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('전화번호가 일치하지 않습니다. 다시 시도해 주세요.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      _verifyPromptShown = false;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (mounted) await _ensureVerified();
    }
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

  Future<void> _naverRegister(String reviewText) async {
    await Clipboard.setData(ClipboardData(text: reviewText));
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('복사 완료'),
        content: const Text(
          '퍼즐 후기 문구가 클립보드에 복사되었습니다.\n네이버 플레이스 리뷰 작성 화면으로 이동합니다.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF03C75A)),
            child: const Text('네이버로 이동'),
          ),
        ],
      ),
    );

    final uri = Uri.tryParse(widget.store.shop.naverReviewDeepLink);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyAndShare(String reviewText) async {
    await Clipboard.setData(ClipboardData(text: reviewText));
    widget.store.saveToSkinJournal(reviewText);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '복사 · 공유 · 피부 일지',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '문구가 복사되었고 SORI 피부 일지에 저장되었습니다.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    final shareText =
                        '오늘 시술 후기예요.\n\n$reviewText\n\n#SORI';
                    await Clipboard.setData(ClipboardData(text: shareText));
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('카카오톡에 붙여넣을 공유 문구를 복사했습니다.'),
                        backgroundColor: MyApp.soriPurple,
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('카카오톡 공유용 복사'),
                  style: FilledButton.styleFrom(backgroundColor: MyApp.soriPurple),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('닫기'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chart = _chart;
    final customer = _customer;

    if (widget.token.trim().isEmpty || chart == null || customer == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F7FC),
        body: Center(child: Text('유효하지 않은 고객 링크입니다')),
      );
    }

    if (!_verified) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F7FC),
        body: Center(
          child: CircularProgressIndicator(color: MyApp.soriPurple),
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
            Text(
              widget.store.shop.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '1:1 피부 진단 리포트',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _ReportCard(customerName: customer.name, chart: chart),
            if (review != null) ...[
              const SizedBox(height: 20),
              const Text(
                '나의 후기',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _ReviewBody(
                review: review,
                isEditing: isEditing,
                onToggle: (s) => widget.store.togglePuzzleSentence(
                  reviewId: review.id,
                  sentence: s,
                ),
                onFinish: _finishEdit,
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
              if (aiReply != null && aiReply.status == AiReplyStatus.ready) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MyApp.soriPurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '원장님께 답글 피드백 요청이 전달되었습니다.',
                    style: TextStyle(color: MyApp.soriPurple, fontSize: 13),
                  ),
                ),
              ],
              if (showMainCta) ...[
                const SizedBox(height: 20),
                DynamicReviewMainAction(
                  isFirstVisit: chart.visitNumber == 1,
                  onNaverRegister: () => _naverRegister(review.displayText),
                  onCopy: () => _copyAndShare(review.displayText),
                  onShare: () => _copyAndShare(review.displayText),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  AiReply? get _aiReply {
    final review = _review;
    if (review == null) return null;
    return widget.store.aiReplyForReview(review.id);
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.customerName, required this.chart});

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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '차트 ${chart.displayChartNo} · ${chart.visitNumber}회차'
            '${chart.careName.isNotEmpty ? ' · ${chart.careName}' : ''}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
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
          if (chart.concernChips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: chart.concernChips
                  .map((c) => Chip(
                        label: Text(c, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({
    required this.review,
    required this.isEditing,
    required this.onToggle,
    required this.onFinish,
  });

  final CustomerReview review;
  final bool isEditing;
  final ValueChanged<String> onToggle;
  final VoidCallback onFinish;

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
          Text(review.displayText, style: const TextStyle(height: 1.5)),
          if (isEditing) ...[
            const SizedBox(height: 12),
            const Text('퍼즐 문장 켜고 끄기', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SoriStore.puzzlePool.map((s) {
                final selected = review.puzzleSelections.contains(s);
                return FilterChip(
                  label: Text(s, style: const TextStyle(fontSize: 12)),
                  selected: selected,
                  onSelected: (_) => onToggle(s),
                  selectedColor: MyApp.soriPurple.withValues(alpha: 0.18),
                  checkmarkColor: MyApp.soriPurple,
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: onFinish,
                style: FilledButton.styleFrom(backgroundColor: MyApp.soriPurple),
                child: const Text('수정 완료'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhoneLast4Dialog extends StatefulWidget {
  const _PhoneLast4Dialog({
    required this.customerName,
    required this.onSubmit,
  });

  final String customerName;
  final bool Function(String last4) onSubmit;

  @override
  State<_PhoneLast4Dialog> createState() => _PhoneLast4DialogState();
}

class _PhoneLast4DialogState extends State<_PhoneLast4Dialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('본인 확인'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.customerName}님, 등록된 전화번호 뒷자리 4자리를 입력해 주세요.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '전화번호 뒷자리 4자리',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.pop(context, widget.onSubmit(_controller.text));
          },
          style: FilledButton.styleFrom(backgroundColor: MyApp.soriPurple),
          child: const Text('확인'),
        ),
      ],
    );
  }
}
