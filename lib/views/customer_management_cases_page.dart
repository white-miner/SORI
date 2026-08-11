import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../models/session_user.dart';
import '../models/shop.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/before_after_slider.dart';
import '../widgets/sori_logo.dart';

/// 고객 모드 전용 — 공유된 관리 케이스 소셜 피드.
class CustomerManagementCasesPage extends StatefulWidget {
  const CustomerManagementCasesPage({super.key, required this.store});

  final SoriStore store;

  @override
  State<CustomerManagementCasesPage> createState() =>
      _CustomerManagementCasesPageState();
}

class _CustomerManagementCasesPageState
    extends State<CustomerManagementCasesPage> {
  final _liked = <String>{};
  final _likeCounts = <String, int>{};
  final _comments = <String, List<_CaseComment>>{};
  int _visibleCount = 8;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  List<({CustomerChart chart, Customer? customer, Shop shop})> get _feed {
    final out = <({CustomerChart chart, Customer? customer, Shop shop})>[];
    for (final chart in widget.store.charts) {
      if (!chart.caseShared || !chart.isConsentSigned) continue;
      final b = chart.beforeImageUrl?.trim() ?? '';
      final a = chart.afterImageUrl?.trim() ?? '';
      if (b.isEmpty && a.isEmpty) continue;
      out.add((
        chart: chart,
        customer: widget.store.findCustomer(chart.customerId),
        shop: widget.store.shop,
      ));
    }
    out.sort((a, b) {
      final ad = a.chart.visitCheckedAt ??
          a.chart.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.chart.visitCheckedAt ??
          b.chart.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return out;
  }

  String _anonymize(String? name) {
    final n = (name ?? '').trim();
    if (n.isEmpty) return '익명 고객님';
    final first = n.characters.first;
    return '$first** 고객님';
  }

  Future<void> _openNaver(Shop shop) async {
    final url = shop.naverPlaceUrl.trim();
    if (url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('네이버 예약 링크가 준비 중입니다.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('네이버 예약 링크가 준비 중입니다.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('네이버 예약 링크가 준비 중입니다.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _toggleLike(String chartId) {
    setState(() {
      final base = _likeCounts[chartId] ?? (3 + chartId.hashCode.abs() % 40);
      if (_liked.contains(chartId)) {
        _liked.remove(chartId);
        _likeCounts[chartId] = (base - 1).clamp(0, 9999);
      } else {
        _liked.add(chartId);
        _likeCounts[chartId] = base + 1;
      }
    });
  }

  void _openComments(CustomerChart chart) {
    final list = _comments.putIfAbsent(chart.id, () => []);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _CommentSheet(
          comments: list,
          onSubmit: (text) {
            final session = widget.store.session;
            final author = session?.name.trim().isNotEmpty == true
                ? session!.name.trim()
                : '고객';
            final isDirector =
                session?.activeMode == UserRole.director;
            setState(() {
              list.add(
                _CaseComment(
                  author: author,
                  body: text,
                  isDirector: isDirector,
                  at: DateTime.now(),
                ),
              );
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = _feed;
    final shown = feed.take(_visibleCount).toList();

    return ColoredBox(
      color: const Color(0xFFF5F6F8),
      child: SafeArea(
        child: shown.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    '아직 공유된 관리 케이스가 없어요.\n곧 다양한 Before/After 사례가 올라올 예정이에요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SoriTokens.textSecondary,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            : NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.pixels >= n.metrics.maxScrollExtent - 120) {
                    if (_visibleCount < feed.length) {
                      setState(() {
                        _visibleCount =
                            (_visibleCount + 6).clamp(0, feed.length);
                      });
                    }
                  }
                  return false;
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final item = shown[index];
                    final id = item.chart.id;
                    final likes =
                        _likeCounts[id] ?? (3 + id.hashCode.abs() % 40);
                    final liked = _liked.contains(id);
                    final comments = _comments[id] ?? const <_CaseComment>[];
                    return _CustomerCaseCard(
                      shop: item.shop,
                      chart: item.chart,
                      anonymousCustomer: _anonymize(item.customer?.name),
                      liked: liked,
                      likeCount: likes,
                      commentCount: comments.length,
                      onLike: () => _toggleLike(id),
                      onComment: () => _openComments(item.chart),
                      onBook: () => _openNaver(item.shop),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _CustomerCaseCard extends StatelessWidget {
  const _CustomerCaseCard({
    required this.shop,
    required this.chart,
    required this.anonymousCustomer,
    required this.liked,
    required this.likeCount,
    required this.commentCount,
    required this.onLike,
    required this.onComment,
    required this.onBook,
  });

  final Shop shop;
  final CustomerChart chart;
  final String anonymousCustomer;
  final bool liked;
  final int likeCount;
  final int commentCount;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final care = chart.careName.isNotEmpty
        ? chart.careName
        : (chart.treatmentSummary.isNotEmpty
            ? chart.treatmentSummary
            : '관리 케어');
    final insight = chart.directorInsight.trim().isNotEmpty
        ? chart.directorInsight.trim()
        : (chart.treatmentSummary.trim().isNotEmpty
            ? chart.treatmentSummary.trim()
            : '시술 후 피부 컨디션이 안정적으로 개선되었어요.');
    final owner = (shop.ownerName ?? '').trim().isEmpty
        ? '원장'
        : shop.ownerName!.trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: SoriTokens.primarySoft,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: SoriLogo(width: 28, height: 28),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '원장 $owner',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          BeforeAfterSlider(
            height: 240,
            before: ChartImagePane(
              url: chart.beforeImageUrl,
              fallbackLabel: 'Before',
              tone: SoriTokens.primary,
            ),
            after: ChartImagePane(
              url: chart.afterImageUrl,
              fallbackLabel: 'After',
              tone: Colors.green.shade700,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  care,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  anonymousCustomer,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  insight,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: onLike,
                  icon: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? const Color(0xFFE53935) : Colors.grey[700],
                  ),
                ),
                Text(
                  '$likeCount',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onComment,
                  icon: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  '$commentCount',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: onBook,
                style: FilledButton.styleFrom(
                  backgroundColor: SoriTokens.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '샵 정보 더보기 / 예약하기',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseComment {
  const _CaseComment({
    required this.author,
    required this.body,
    required this.isDirector,
    required this.at,
  });

  final String author;
  final String body;
  final bool isDirector;
  final DateTime at;
}

class _CommentSheet extends StatefulWidget {
  const _CommentSheet({
    required this.comments,
    required this.onSubmit,
  });

  final List<_CaseComment> comments;
  final ValueChanged<String> onSubmit;

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.55,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '댓글',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Expanded(
              child: widget.comments.isEmpty
                  ? Center(
                      child: Text(
                        '첫 댓글을 남겨 보세요',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      itemCount: widget.comments.length,
                      itemBuilder: (context, i) {
                        final c = widget.comments[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: c.isDirector
                                    ? SoriTokens.primarySoft
                                    : const Color(0xFFEEF2F7),
                                child: Icon(
                                  c.isDirector
                                      ? Icons.storefront_outlined
                                      : Icons.person_outline,
                                  size: 16,
                                  color: c.isDirector
                                      ? SoriTokens.primary
                                      : Colors.grey[700],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.isDirector
                                          ? '${c.author} · 원장'
                                          : c.author,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      c.body,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: '댓글을 입력하세요',
                        filled: true,
                        fillColor: const Color(0xFFF5F6F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    style: IconButton.styleFrom(
                      backgroundColor: SoriTokens.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
