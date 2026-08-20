import 'package:flutter/material.dart';

import '../models/session_user.dart';
import '../models/shop.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../views/seminar_management_page.dart';
import '../widgets/shop_tier_badge_chip.dart';

/// PC 와이드 뷰포트에서 피드 우측에 고정되는 대시보드/댓글 사이드바.
/// [dashboardOnly] true이면 항상 대시보드만 표시 (우측 끝단용).
class RightSidebar extends StatefulWidget {
  const RightSidebar({super.key, this.dashboardOnly = false});

  final bool dashboardOnly;
  static const double width = 320;

  @override
  State<RightSidebar> createState() => _RightSidebarState();
}

class _RightSidebarState extends State<RightSidebar> {
  final _store = SoriStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onChanged);
  }

  @override
  void dispose() {
    _store.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dashboardOnly) {
      return const SizedBox(
        width: RightSidebar.width,
        child: _DashboardPanel(),
      );
    }

    final postId = _store.activeCommentPostId;

    return SizedBox(
      width: postId != null ? double.infinity : RightSidebar.width,
      child: postId != null
          ? _CommentPanel(key: ValueKey(postId), postId: postId)
          : const _DashboardPanel(key: ValueKey('dashboard')),
    );
  }
}

// ─── Dashboard (default state) ───────────────────────────────────────────────

class _DashboardPanel extends StatefulWidget {
  const _DashboardPanel({super.key});

  @override
  State<_DashboardPanel> createState() => _DashboardPanelState();
}

class _DashboardPanelState extends State<_DashboardPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = SoriStore.instance;
      if (store.session?.activeMode == UserRole.director) {
        store.refreshSeminarEducationInsight();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = SoriStore.instance;
    final session = store.session;
    if (session == null) return const SizedBox.shrink();

    final shop = store.shop;
    final month = DateTime.now().month;
    final reqCount = store.seminarEducationInsight?.totalRequests ??
        store.seminarEducationInsight?.seminarRequestCount ??
        shop.seminarRequestCount;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      children: [
        _TierCard(shop: shop),
        const SizedBox(height: 12),
        _AiSummaryCard(month: month),
        const SizedBox(height: 12),
        _SeminarCard(
          count: reqCount,
          onTap: () => SeminarManagementPage.open(context, store: store),
        ),
      ],
    );
  }
}

// ─── Comment Panel (active state) ────────────────────────────────────────────

class _CommentPanel extends StatefulWidget {
  const _CommentPanel({super.key, required this.postId});
  final String postId;

  @override
  State<_CommentPanel> createState() => _CommentPanelState();
}

class _CommentPanelState extends State<_CommentPanel> {
  final _controller = TextEditingController();
  final _comments = <_SideComment>[];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final store = SoriStore.instance;
    final name = store.session?.name ?? '나';
    setState(() {
      _comments.add(_SideComment(author: name, body: text, at: DateTime.now()));
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: SoriTokens.surface,
          border: const Border(
            left: BorderSide(color: SoriTokens.outlinePurple, width: 1.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(-4, 0),
            ),
          ],
        ),
        child: Column(
          children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '댓글',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => SoriStore.instance.closeCommentPanel(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Comment list
          Expanded(
            child: _comments.isEmpty
                ? Center(
                    child: Text(
                      '첫 댓글을 남겨 보세요',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    itemCount: _comments.length,
                    itemBuilder: (_, i) {
                      final c = _comments[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: SoriTokens.primarySoft,
                              child: Text(
                                c.author.isNotEmpty ? c.author[0] : '?',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: SoriTokens.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.author,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    c.body,
                                    style: const TextStyle(fontSize: 13),
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
          // Input
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: SoriTokens.outlinePurple, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: '댓글을 입력하세요',
                      hintStyle: const TextStyle(color: SoriTokens.textSecondary),
                      filled: true,
                      fillColor: SoriTokens.background,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: SoriTokens.textPrimary,
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _submit,
                  icon: const Icon(Icons.send_rounded,
                      color: SoriTokens.primary, size: 20),
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

class _SideComment {
  const _SideComment({
    required this.author,
    required this.body,
    required this.at,
  });
  final String author;
  final String body;
  final DateTime at;
}

// ─── Dashboard Cards ─────────────────────────────────────────────────────────

class _TierCard extends StatelessWidget {
  const _TierCard({required this.shop});
  final Shop shop;

  @override
  Widget build(BuildContext context) {
    final snap = shop.tierProgress;
    final pct = ((snap.socialRatio > snap.businessRatio
                ? snap.socialRatio
                : snap.businessRatio) *
            100)
        .round()
        .clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SoriTokens.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.military_tech_rounded,
                  size: 20, color: Color(0xFFFBBF24)),
              const SizedBox(width: 6),
              const Text('내 등급',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: SoriTokens.textPrimary,
                  )),
              const Spacer(),
              ShopTierBadgeChip(badge: shop.tierBadge, compact: true),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 6,
              backgroundColor: SoriTokens.primarySoft,
              color: SoriTokens.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '달성률 $pct%',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: SoriTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiSummaryCard extends StatelessWidget {
  const _AiSummaryCard({required this.month});
  final int month;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SoriTokens.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph_rounded,
                  size: 20, color: Color(0xFF2DD4BF)),
              const SizedBox(width: 6),
              Text('AI 경영 · $month월',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '이번 달 AI 리포트를 확인하세요',
            style: TextStyle(
              fontSize: 12,
              color: SoriTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeminarCard extends StatelessWidget {
  const _SeminarCard({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: SoriTokens.card(radius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.school_rounded, size: 20, color: SoriTokens.primary),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      '추천 세미나',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: SoriTokens.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: SoriTokens.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                count > 0 ? '관심 $count건' : '세미나 둘러보기',
                style: const TextStyle(
                  fontSize: 12,
                  color: SoriTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
