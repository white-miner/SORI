import 'package:flutter/material.dart';

import '../models/session_user.dart';
import '../models/shop.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../views/seminar_management_page.dart';
import '../widgets/shop_tier_badge_chip.dart';
import '../widgets/glass/sori_glass_fab.dart';
import '../widgets/glass/sori_glass_icon_button.dart';
import '../widgets/glass/sori_glass_tokens.dart';
import '../widgets/sori_glass_surface.dart';

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
                SoriGlassIconButton(
                  icon: Icons.close_rounded,
                  onPressed: () => SoriStore.instance.closeCommentPanel(),
                  tooltip: '닫기',
                  size: SoriGlassTokens.chipSm,
                  iconSize: 18,
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
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: SoriTokens.outlinePurple, width: 1),
              ),
            ),
            child: SoriGlassInputBar(
              controller: _controller,
              hint: '댓글을 입력하세요',
              onSend: _submit,
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

    return SoriGlassSurface(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.military_tech_rounded,
                  size: 20, color: SoriTokens.warningText),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              final fillWidth = trackWidth * (pct / 100);
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 6,
                  width: trackWidth,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: SoriTokens.chipIdleBg),
                      if (fillWidth > 0)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: fillWidth,
                            height: 6,
                            child: const ColoredBox(
                              color: SoriTokens.accentLink,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
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
    return SoriGlassSurface(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph_rounded,
                  size: 20, color: SoriTokens.primary),
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
        child: SoriGlassSurface(
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.all(16),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
