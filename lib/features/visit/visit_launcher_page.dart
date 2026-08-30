import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../visit_kernel/models/visit_session.dart';
import '../../visit_kernel/theme/visit_glass_tokens.dart';
import '../../visit_kernel/visit_store.dart';
import '../../visit_kernel/widgets/visit_glass_widgets.dart';
import 'visit_customer_picker_sheet.dart';
import 'visit_session_page.dart';

/// Visit Launcher — 오늘 방문 세션 시작 (Today Board 완전 대체, PRD v3.0).
class VisitLauncherPage extends StatefulWidget {
  const VisitLauncherPage({super.key, required this.store});

  final SoriStore store;

  @override
  State<VisitLauncherPage> createState() => _VisitLauncherPageState();
}

class _VisitLauncherPageState extends State<VisitLauncherPage> {
  bool _loading = true;

  VisitStore get visit => widget.store.visit;

  @override
  void initState() {
    super.initState();
    visit.addListener(_onVisit);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    visit.removeListener(_onVisit);
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _loading = true);
    await visit.ensureLoaded(force: force);
    if (mounted) setState(() => _loading = false);
  }

  void _onVisit() {
    if (mounted) setState(() {});
  }

  String get _greetingName {
    final owner = widget.store.shop.ownerName?.trim();
    if (owner != null && owner.isNotEmpty) return owner;
    final session = widget.store.session?.name.trim();
    if (session != null && session.isNotEmpty) return session;
    return '원장';
  }

  Future<void> _startVisit() async {
    final customer = await showVisitCustomerPickerSheet(
      context,
      store: widget.store,
    );
    if (customer == null || !mounted) return;

    try {
      final session = await visit.startVisit(customer);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VisitSessionPage(
            store: widget.store,
            sessionId: session.id,
          ),
        ),
      );
      await _load(force: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('방문 시작 실패: $e')),
      );
    }
  }

  void _openSession(VisitSession session) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisitSessionPage(
          store: widget.store,
          sessionId: session.id,
        ),
      ),
    ).then((_) => _load(force: true));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final snap = visit.snapshotForDay(day);

    return ColoredBox(
      color: SoriTokens.background,
      child: RefreshIndicator(
        color: VisitGlassTokens.care,
        onRefresh: () => _load(force: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  '안녕하세요, $_greetingName 원장님',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: VisitGlassTokens.heroDecoration(),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘의 방문',
                        style: VisitGlassTokens.captionCalm.copyWith(
                          color: VisitGlassTokens.care,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${snap.sessions.length}',
                            style: VisitGlassTokens.displayKpi(context),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '세션',
                              style: VisitGlassTokens.bodyCalm.copyWith(
                                color: SoriTokens.textSecondary,
                              ),
                            ),
                          ),
                          const Spacer(),
                          VisitProgressRing(
                            ratio: snap.progressRatio,
                            size: 52,
                            label: snap.sessions.isEmpty
                                ? '—'
                                : '${snap.completedCount}/${snap.sessions.length}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _startVisit,
                          icon: const Icon(Icons.favorite_rounded),
                          label: const Text('방문 시작'),
                          style: FilledButton.styleFrom(
                            backgroundColor: VisitGlassTokens.care,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '고객님과 마주 앉을 때 가장 먼저 켜는 앱',
                        style: VisitGlassTokens.captionCalm.copyWith(
                          color: SoriTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snap.sessions.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      '오늘 시작한 방문이 없어요.\n손님을 맞이할 준비가 되면\n「방문 시작」을 눌러 주세요.',
                      textAlign: TextAlign.center,
                      style: VisitGlassTokens.bodyCalm.copyWith(
                        color: SoriTokens.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                sliver: SliverList.separated(
                  itemCount: snap.sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final session = snap.sessions[i];
                    return _VisitSessionTile(
                      session: session,
                      store: widget.store,
                      onTap: () => _openSession(session),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VisitSessionTile extends StatelessWidget {
  const _VisitSessionTile({
    required this.session,
    required this.store,
    required this.onTap,
  });

  final VisitSession session;
  final SoriStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chart = store.chartForVisitSession(session);
    final hasBefore = chart?.beforeImageUrl?.trim().isNotEmpty == true;
    final hasAfter = chart?.afterImageUrl?.trim().isNotEmpty == true;
    final isActive = session.isActive;
    final time =
        '${session.startedAt.hour.toString().padLeft(2, '0')}:${session.startedAt.minute.toString().padLeft(2, '0')}';

    return VisitGlassCard(
      socialGlow: isActive,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VisitGlassTokens.care.withValues(alpha: 0.18),
            ),
            child: Icon(
              isActive ? Icons.auto_awesome : Icons.check_rounded,
              color: VisitGlassTokens.care,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.customerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$time · ${session.phase.label}',
                  style: VisitGlassTokens.captionCalm.copyWith(
                    color: SoriTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PhotoDot(active: hasBefore, label: 'B'),
              const SizedBox(width: 4),
              _PhotoDot(active: hasAfter, label: 'A'),
            ],
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: SoriTokens.textSecondary.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}

class _PhotoDot extends StatelessWidget {
  const _PhotoDot({required this.active, required this.label});

  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? VisitGlassTokens.sage.withValues(alpha: 0.35)
            : SoriTokens.border.withValues(alpha: 0.4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: active ? VisitGlassTokens.sage : SoriTokens.textSecondary,
        ),
      ),
    );
  }
}
