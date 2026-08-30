import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/community_comment.dart';
import '../services/sori_store.dart';
import '../services/supabase_client.dart';
import '../theme/sori_tokens.dart';

/// Community 포스트 댓글 — Supabase Realtime + SSOT.
class CommunityCommentsSection extends StatefulWidget {
  const CommunityCommentsSection({
    super.key,
    required this.store,
    required this.postId,
    this.embeddedInSidebar = false,
  });

  final SoriStore store;
  final String postId;
  final bool embeddedInSidebar;

  @override
  State<CommunityCommentsSection> createState() =>
      _CommunityCommentsSectionState();
}

class _CommunityCommentsSectionState extends State<CommunityCommentsSection> {
  final _ctrl = TextEditingController();
  List<CommunityComment> _roots = [];
  bool _loading = true;
  bool _sending = false;
  String? _replyToId;
  String? _replyToName;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _reload();
    _subscribe();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    final ch = _channel;
    if (ch != null) {
      unawaited(SoriSupabase.clientOrNull?.removeChannel(ch) ?? Future.value());
    }
    super.dispose();
  }

  Future<void> _reload() async {
    final list =
        await widget.store.loadCommunityComments(widget.postId);
    if (!mounted) return;
    setState(() {
      _roots = list;
      _loading = false;
    });
  }

  void _subscribe() {
    final client = SoriSupabase.clientOrNull;
    if (client == null) return;
    final postId = widget.postId.trim();
    if (postId.isEmpty) return;
    try {
      _channel = client
          .channel('community_comments_$postId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'community_comments',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'post_id',
              value: postId,
            ),
            callback: (_) {
              unawaited(_reload());
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('community comments realtime skip: $e');
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final created = await widget.store.addCommunityComment(
      postId: widget.postId,
      content: text,
      parentId: _replyToId,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (created != null) {
        _ctrl.clear();
        _replyToId = null;
        _replyToName = null;
      }
    });
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final titlePad = widget.embeddedInSidebar
        ? const EdgeInsets.fromLTRB(14, 12, 14, 6)
        : const EdgeInsets.fromLTRB(14, 8, 14, 6);

    final listSection = _loading
        ? const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        : _roots.isEmpty
            ? Padding(
                padding: EdgeInsets.fromLTRB(
                  14,
                  4,
                  14,
                  widget.embeddedInSidebar ? 12 : 12,
                ),
                child: const Text(
                  '첫 댓글로 소통을 시작해 보세요',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: SoriTokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : widget.embeddedInSidebar
                ? ListView(
                    padding: const EdgeInsets.only(bottom: 8),
                    children: _roots.map(_buildThread).toList(),
                  )
                : Column(
                    children: _roots.map(_buildThread).toList(),
                  );

    final inputRow = Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, widget.embeddedInSidebar ? 8 : 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '의견을 남겨 주세요',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _sending ? null : _send,
            style: IconButton.styleFrom(
              backgroundColor: SoriTokens.primary,
            ),
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
          ),
        ],
      ),
    );

    if (widget.embeddedInSidebar) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: titlePad,
            child: const Text(
              '댓글',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
          if (_replyToId != null) _replyBanner(),
          Expanded(child: listSection),
          inputRow,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 8, 14, 6),
          child: Text(
            '댓글',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ),
        listSection,
        if (_replyToId != null) _replyBanner(),
        inputRow,
      ],
    );
  }

  Widget _replyBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_replyToName ?? '댓글'}에 답글',
              style: const TextStyle(
                fontSize: 12,
                color: SoriTokens.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              _replyToId = null;
              _replyToName = null;
            }),
            child: const Text('취소', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildThread(CommunityComment c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentBubble(
            comment: c,
            onReply: () => setState(() {
              _replyToId = c.id;
              _replyToName = c.displayName;
            }),
          ),
          for (final r in c.replies)
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 8),
              child: _CommentBubble(
                comment: r,
                isReply: true,
                onReply: () => setState(() {
                  _replyToId = c.id;
                  _replyToName = c.displayName;
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble({
    required this.comment,
    required this.onReply,
    this.isReply = false,
  });

  final CommunityComment comment;
  final VoidCallback onReply;
  final bool isReply;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: isReply
            ? SoriTokens.background
            : SoriTokens.primarySoft.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SoriTokens.outlinePurple.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            comment.displayName,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            comment.content,
            style: const TextStyle(fontSize: 13.5, height: 1.45),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onReply,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 28),
              ),
              child: const Text('답글', style: TextStyle(fontSize: 11.5)),
            ),
          ),
        ],
      ),
    );
  }
}
