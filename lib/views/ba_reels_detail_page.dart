import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/community_case_item.dart';
import '../models/customer_review.dart';
import '../models/session_user.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

/// Reels 스타일 세로 풀스크린 B/A 디테일.
class BaReelsDetailPage extends StatefulWidget {
  const BaReelsDetailPage({
    super.key,
    required this.store,
    required this.items,
    this.initialIndex = 0,
  });

  final SoriStore store;
  final List<CommunityCaseItem> items;
  final int initialIndex;

  @override
  State<BaReelsDetailPage> createState() => _BaReelsDetailPageState();
}

class _BaReelsDetailPageState extends State<BaReelsDetailPage> {
  late final PageController _pageController;
  final _liked = <String>{};
  final _likeCounts = <String, int>{};
  final _comments = <String, List<_ReelComment>>{};

  @override
  void initState() {
    super.initState();
    final i = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: i);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleLike(String chartId) {
    setState(() {
      final base = _likeCounts[chartId] ?? (12 + chartId.hashCode.abs() % 80);
      if (_liked.contains(chartId)) {
        _liked.remove(chartId);
        _likeCounts[chartId] = (base - 1).clamp(0, 9999);
      } else {
        _liked.add(chartId);
        _likeCounts[chartId] = base + 1;
      }
    });
  }

  void _openComments(String chartId) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200) {
      if (widget.store.activeCommentPostId == chartId) {
        widget.store.closeCommentPanel();
      } else {
        widget.store.openCommentPanel(chartId);
      }
      return;
    }
    final list = _comments.putIfAbsent(chartId, () => []);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _ReelCommentSheet(
          comments: list,
          onSubmit: (text) {
            final session = widget.store.session;
            final author = session?.name.trim().isNotEmpty == true
                ? session!.name.trim()
                : '고객';
            setState(() {
              list.add(
                _ReelComment(
                  author: author,
                  body: text,
                  isDirector: session?.activeMode == UserRole.director,
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
    if (widget.items.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('케이스가 없습니다', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.items.length,
            allowImplicitScrolling: true,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final id = item.chart.id;
              final likes =
                  _likeCounts[id] ?? (12 + id.hashCode.abs() % 80);
              final liked = _liked.contains(id);
              final commentCount = _comments[id]?.length ?? 0;
              final review =
                  item.review ?? widget.store.reviewForChart(id);
              return _ReelPage(
                item: item,
                review: review,
                liked: liked,
                likeCount: likes,
                commentCount: commentCount,
                onLike: () => _toggleLike(id),
                onComment: () => _openComments(id),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black45,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      '위로 스와이프 · B/A',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelPage extends StatelessWidget {
  const _ReelPage({
    required this.item,
    required this.liked,
    required this.likeCount,
    required this.commentCount,
    required this.onLike,
    required this.onComment,
    this.review,
  });

  final CommunityCaseItem item;
  final CustomerReview? review;
  final bool liked;
  final int likeCount;
  final int commentCount;
  final VoidCallback onLike;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    final chart = item.chart;
    final after = chart.afterImageUrl?.trim() ?? '';
    final before = chart.beforeImageUrl?.trim() ?? '';
    final imageUrl = after.isNotEmpty ? after : before;
    final care = chart.careName.trim().isNotEmpty
        ? chart.careName.trim()
        : '관리 케이스';
    final tag = chart.concernChips.isNotEmpty
        ? '#${chart.concernChips.first}'
        : (care.startsWith('#') ? care : '#$care');
    final reviewText = review?.displayText.trim() ?? '';
    final reply = review?.directorReply?.trim() ?? '';
    final owner = (item.shop.ownerName ?? '').trim().isEmpty
        ? '원장'
        : item.shop.ownerName!.trim();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl.isNotEmpty)
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => Container(
              color: const Color(0xFF1A1A1A),
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined,
                  color: Colors.white54, size: 48),
            ),
          )
        else
          Container(
            color: const Color(0xFF1A1A1A),
            alignment: Alignment.center,
            child: Text(
              care,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.transparent,
                Color(0x99000000),
                Color(0xCC000000),
              ],
              stops: [0.0, 0.45, 0.75, 1.0],
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 88,
          bottom: 28,
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.shop.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  care,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (reviewText.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '💬 $reviewText',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (reply.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '↳ 👑 $owner: $reply',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 36,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                _ReelActionButton(
                  icon: liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? const Color(0xFFFF4D6D) : Colors.white,
                  label: '$likeCount',
                  onTap: onLike,
                ),
                const SizedBox(height: 18),
                _ReelActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                  label: '$commentCount',
                  onTap: onComment,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReelActionButton extends StatelessWidget {
  const _ReelActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.black38,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: color, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ReelComment {
  const _ReelComment({
    required this.author,
    required this.body,
    required this.isDirector,
  });

  final String author;
  final String body;
  final bool isDirector;
}

class _ReelCommentSheet extends StatefulWidget {
  const _ReelCommentSheet({
    required this.comments,
    required this.onSubmit,
  });

  final List<_ReelComment> comments;
  final ValueChanged<String> onSubmit;

  @override
  State<_ReelCommentSheet> createState() => _ReelCommentSheetState();
}

class _ReelCommentSheetState extends State<_ReelCommentSheet> {
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
        height: MediaQuery.sizeOf(context).height * 0.5,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SoriTokens.border,
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
                    color: SoriTokens.textPrimary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: widget.comments.isEmpty
                  ? const Center(
                      child: Text(
                        '첫 댓글을 남겨 보세요',
                        style: TextStyle(color: SoriTokens.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      itemCount: widget.comments.length,
                      itemBuilder: (context, i) {
                        final c = widget.comments[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                color: SoriTokens.textPrimary,
                              ),
                              children: [
                                TextSpan(
                                  text: c.isDirector
                                      ? '${c.author} · 원장  '
                                      : '${c.author}  ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: SoriTokens.textPrimary,
                                  ),
                                ),
                                TextSpan(text: c.body),
                              ],
                            ),
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
                        hintText: '댓글 입력',
                        filled: true,
                        fillColor: SoriTokens.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
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
