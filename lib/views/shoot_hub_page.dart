import 'dart:async';

import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../models/shoot_inbox_item.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_shell_insets.dart';
import '../features/visit/visit_session_page.dart';
import '../visit_kernel/theme/visit_glass_tokens.dart';
import 'smart_guide_camera_page.dart';

/// 같은 sessionToken 의 Before/After 한 묶음.
class ShootInboxSession {
  const ShootInboxSession({
    required this.token,
    this.before,
    this.after,
  });

  final String token;
  final ShootInboxItem? before;
  final ShootInboxItem? after;

  bool get hasBefore => before != null;
  bool get hasAfter => after != null;

  /// 고객 연결에 쓸 대표 항목 (Before 우선).
  ShootInboxItem? get primary => before ?? after;
}

/// 미연결 큐를 세션 단위로 묶는다. 토큰이 없는 항목은 단독 세션.
/// 세션당 Before·After는 각각 최대 1장만 남긴다 (1:1).
List<ShootInboxSession> groupShootInboxSessions(List<ShootInboxItem> inbox) {
  final order = <String>[];
  final map = <String, List<ShootInboxItem>>{};
  for (final item in inbox) {
    final token = item.sessionToken.trim().isEmpty
        ? 'legacy-${item.id}'
        : item.sessionToken.trim();
    if (!map.containsKey(token)) {
      order.add(token);
      map[token] = [];
    }
    map[token]!.add(item);
  }

  return [
    for (final token in order)
      () {
        ShootInboxItem? before;
        ShootInboxItem? after;
        for (final item in map[token]!) {
          if (item.isBefore) {
            before ??= item;
          } else if (item.isAfter) {
            after ??= item;
          }
        }
        return ShootInboxSession(
          token: token,
          before: before,
          after: after,
        );
      }(),
  ];
}

/// 미연결 썸네일용 촬영 시각. 예: `09.10 14:30`
String formatShootInboxStamp(DateTime? at) {
  if (at == null) return '';
  final t = at.toLocal();
  final mm = t.month.toString().padLeft(2, '0');
  final dd = t.day.toString().padLeft(2, '0');
  final hh = t.hour.toString().padLeft(2, '0');
  final min = t.minute.toString().padLeft(2, '0');
  return '$mm.$dd $hh:$min';
}

/// 원장 GNB 중앙 「촬영」허브 — C1~C3.
class ShootHubPage extends StatefulWidget {
  const ShootHubPage({super.key, required this.store});

  final SoriStore store;

  @override
  State<ShootHubPage> createState() => _ShootHubPageState();
}

class _ShootHubPageState extends State<ShootHubPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  Customer? _selected;
  bool _busy = false;

  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(store.refreshShootInbox());
      unawaited(store.refreshVisitSessions());
    });
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  List<Customer> get _filtered {
    final q = _query.trim().toLowerCase();
    final all = store.customers;
    if (q.isEmpty) {
      final sorted = List<Customer>.from(all)
        ..sort((a, b) => b.lastTreatmentDate.compareTo(a.lastTreatmentDate));
      return sorted.take(40).toList();
    }
    return all
        .where((c) {
          final name = c.name.toLowerCase();
          final phone = c.phone.replaceAll(RegExp(r'\D'), '');
          final qq = q.replaceAll(RegExp(r'\D'), '');
          return name.contains(q) ||
              (qq.isNotEmpty && phone.contains(qq));
        })
        .take(40)
        .toList();
  }

  List<({Customer customer, CustomerChart chart})> get _afterWaiting =>
      store.shootAfterWaiting().take(20).toList();

  List<ShootInboxSession> get _sessions =>
      groupShootInboxSessions(store.shootInbox);

  Future<void> _shootExisting({
    required Customer customer,
    required GuideCameraKind kind,
    CustomerChart? targetChart,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final active = store.activeVisitSession;
      CustomerChart? chart = targetChart;
      if (chart == null &&
          active != null &&
          active.customerId == customer.id) {
        chart = store.chartForVisitSession(active);
      }
      chart ??= await store.ensureTodayShootChart(customerId: customer.id);
      if (!mounted) return;

      final ghost = kind == GuideCameraKind.after
          ? (targetChart?.beforeImageUrl ?? chart.beforeImageUrl)
          : null;

      final result = await SmartGuideCameraPage.open(
        context,
        shopId: store.shop.id,
        customerId: customer.id,
        kind: kind,
        ghostBeforeUrl: ghost,
      );
      if (!mounted || result == null) return;

      if (result.kind == GuideCameraKind.before) {
        await store.updateCustomerChartFields(
          chartId: chart.id,
          beforeImageUrl: result.url,
        );
      } else {
        await store.patchChartAfterImage(
          chartId: chart.id,
          afterImageUrl: result.url,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('촬영 저장 실패: $e'),
          backgroundColor: SoriTokens.systemRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 미연결 촬영. 라벨 팝업·스낵바 없이 큐에만 넣고 바로 허브로 돌아온다.
  ///
  /// Before는 항상 새 세션. After는 [sessionToken]/[ghostBeforeUrl]로
  /// 짝 Before에 묶인다.
  Future<void> _shootUnbound({
    required GuideCameraKind kind,
    String? sessionToken,
    String? ghostBeforeUrl,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final token = kind == GuideCameraKind.before
          ? 'sess-${DateTime.now().millisecondsSinceEpoch}'
          : (sessionToken ??
              'sess-${DateTime.now().millisecondsSinceEpoch}');
      final ghost =
          kind == GuideCameraKind.after ? ghostBeforeUrl : null;

      final result = await SmartGuideCameraPage.open(
        context,
        shopId: store.shop.id,
        customerId: 'unbound',
        kind: kind,
        ghostBeforeUrl: ghost,
      );
      // 촬영 없이 닫으면 아무 팝업도 없이 허브로만 돌아온다.
      if (!mounted || result == null) return;

      // 1:1 — 같은 세션에 After가 이미 있으면 새 장으로 덮지 않고 교체한다.
      if (result.kind == GuideCameraKind.after) {
        final stale = store.shootInbox
            .where((e) => e.sessionToken == token && e.isAfter)
            .map((e) => e.id)
            .toList();
        for (final id in stale) {
          await store.dismissShootInboxItem(id);
        }
      }

      await store.enqueueShootInboxItem(
        ShootInboxItem(
          id: 'inbox-${DateTime.now().microsecondsSinceEpoch}',
          shopId: store.shop.id,
          kind: result.kind == GuideCameraKind.before ? 'before' : 'after',
          imageUrl: result.url,
          label: '미등록',
          sessionToken: token,
          createdAt: DateTime.now(),
          ghostBeforeUrl: ghost,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('임시 촬영 실패: $e'),
          backgroundColor: SoriTokens.systemRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bindSession(ShootInboxSession session) async {
    final primary = session.primary;
    if (primary == null) return;
    final customer = await _pickCustomerForBind();
    if (customer == null || !mounted) return;
    setState(() => _busy = true);
    try {
      if (session.before != null) {
        await store.bindShootInboxToCustomer(
          inboxId: session.before!.id,
          customerId: customer.id,
        );
      }
      if (session.after != null &&
          store.shootInbox.any((e) => e.id == session.after!.id)) {
        await store.bindShootInboxToCustomer(
          inboxId: session.after!.id,
          customerId: customer.id,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('연결 실패: $e'),
          backgroundColor: SoriTokens.systemRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dismissSession(ShootInboxSession session) async {
    for (final item in [session.before, session.after]) {
      if (item != null) {
        await store.dismissShootInboxItem(item.id);
      }
    }
  }

  /// 슬롯 하나만 지운다. After만 지우면 빈 카메라 슬롯으로 돌아간다.
  Future<void> _dismissSlot(ShootInboxItem item) async {
    await store.dismissShootInboxItem(item.id);
  }

  Future<Customer?> _pickCustomerForBind() async {
    return showModalBottomSheet<Customer>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        var q = '';
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final rows = store.customers.where((c) {
              if (q.trim().isEmpty) return true;
              final qq = q.trim().toLowerCase();
              final digits = qq.replaceAll(RegExp(r'\D'), '');
              return c.name.toLowerCase().contains(qq) ||
                  (digits.isNotEmpty && c.phone.contains(digits));
            }).take(30);
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(ctx).height * 0.65,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                      '고객에게 연결',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: '이름·전화 검색',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) => setModal(() => q = v),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final c in rows)
                            ListTile(
                              title: Text(c.name),
                              subtitle: Text(c.phone),
                              onTap: () => Navigator.pop(ctx, c),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _afterWaiting;
    final sessions = _sessions;

    return ColoredBox(
      color: SoriTokens.background,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              key: const Key('shoot-hub-list'),
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                16 + SoriShellInsets.scrollBottomInset(context),
              ),
              children: [
                const Text(
                  '촬영',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                if (store.activeVisitSession case final session?) ...[
                  const SizedBox(height: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => VisitSessionPage(
                              store: store,
                              sessionId: session.id,
                              track: VisitSessionPage.resolveTrack(
                                store,
                                session,
                              ),
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: VisitGlassTokens.cardDecoration(
                          socialGlow: true,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.favorite_rounded,
                              color: VisitGlassTokens.care,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '진행 중 · ${session.customerName}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${session.phase.label} 단계',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: SoriTokens.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                const Text(
                  '바로 찍고 나중에 고객에게 연결하세요. 고객을 먼저 고르고 싶으면 아래에서 찾으면 됩니다.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: SoriTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                  FilledButton.icon(
                  key: const Key('shoot-now-before'),
                  onPressed: _busy
                      ? null
                      : () => _shootUnbound(kind: GuideCameraKind.before),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: const Text(
                    '지금 바로 전(前) 촬영',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: SoriTokens.brand,
                    foregroundColor: SoriTokens.onBrand,
                  ),
                ),
                if (waiting.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    '후(後) 대기 · ${waiting.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: waiting.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final row = waiting[i];
                        return _WaitingChip(
                          name: row.customer.name,
                          visitLabel: '${row.chart.visitNumber}회',
                          onTap: () => _shootExisting(
                            customer: row.customer,
                            kind: GuideCameraKind.after,
                            targetChart: row.chart,
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (sessions.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    '미연결 · ${sessions.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '빈 후(後) 칸을 누르면 짝 사진을 찍어요. 사진을 길게 누르면 고객에게 연결합니다.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: SoriTokens.textTertiary,
                    ),
                  ),
                  // Before | After 가 한 줄의 2열. 썸네일은 예전 48px의 ~2.5배 이상.
                  for (final session in sessions) ...[
                    const SizedBox(height: 10),
                    _SessionPairCard(
                      session: session,
                      onShootAfter: session.hasBefore && !session.hasAfter
                          ? () => _shootUnbound(
                                kind: GuideCameraKind.after,
                                sessionToken: session.token,
                                ghostBeforeUrl: session.before!.imageUrl,
                              )
                          : null,
                      onBind: () => unawaited(_bindSession(session)),
                      onDismissSession: () =>
                          unawaited(_dismissSession(session)),
                      onDismissBefore: session.before != null
                          ? () => unawaited(_dismissSlot(session.before!))
                          : null,
                      onDismissAfter: session.after != null
                          ? () => unawaited(_dismissSlot(session.after!))
                          : null,
                    ),
                  ],
                ],
                const SizedBox(height: 18),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(color: SoriTokens.textPrimary),
                  decoration: InputDecoration(
                    hintText: '고객 이름·전화 검색',
                    hintStyle:
                        const TextStyle(color: SoriTokens.textQuaternary),
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: SoriTokens.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_selected != null) ...[
                  const SizedBox(height: 14),
                  _SelectedCard(
                    customer: _selected!,
                    onClear: () => setState(() => _selected = null),
                    onBefore: () => _shootExisting(
                      customer: _selected!,
                      kind: GuideCameraKind.before,
                    ),
                    onAfter: () => _shootExisting(
                      customer: _selected!,
                      kind: GuideCameraKind.after,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  _query.trim().isEmpty ? '최근 고객' : '검색 결과',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: SoriTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ..._filtered.map((c) {
                  final selected = _selected?.id == c.id;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: selected
                          ? SoriTokens.primarySoft
                          : SoriTokens.surfaceOverlay,
                      child: Text(
                        c.name.isNotEmpty ? c.name.characters.first : '?',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    title: Text(
                      c.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      c.phone.isNotEmpty ? c.phone : '연락처 없음',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: SoriTokens.textTertiary,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(
                            Icons.check_circle,
                            color: SoriTokens.primary,
                          )
                        : null,
                    onTap: () => setState(() => _selected = c),
                  );
                }),
                if (_filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        '검색 결과가 없어요',
                        style: TextStyle(color: SoriTokens.textTertiary),
                      ),
                    ),
                  ),
              ],
            ),
            if (_busy)
              const ModalBarrier(
                dismissible: false,
                color: Color(0x66000000),
              ),
            if (_busy)
              const Center(
                child: CircularProgressIndicator(color: SoriTokens.primary),
              ),
          ],
        ),
      ),
    );
  }
}

class _WaitingChip extends StatelessWidget {
  const _WaitingChip({
    required this.name,
    required this.visitLabel,
    required this.onTap,
  });

  final String name;
  final String visitLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 84,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SoriTokens.primary.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: SoriTokens.primarySoft,
                child: Text(
                  name.isNotEmpty ? name.characters.first : '?',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                visitLabel,
                style: const TextStyle(
                  fontSize: 10,
                  color: SoriTokens.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Before | After 페어 한 칸. 빈 After 는 카메라 진입 슬롯.
class _SessionPairCard extends StatelessWidget {
  const _SessionPairCard({
    required this.session,
    required this.onShootAfter,
    required this.onBind,
    required this.onDismissSession,
    this.onDismissBefore,
    this.onDismissAfter,
  });

  final ShootInboxSession session;
  final VoidCallback? onShootAfter;
  final VoidCallback onBind;
  final VoidCallback onDismissSession;
  final VoidCallback? onDismissBefore;
  final VoidCallback? onDismissAfter;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Spacer(),
                IconButton(
                  tooltip: '세션 전체 삭제',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: onDismissSession,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _PairSlot(
                    label: '전',
                    item: session.before,
                    emptyIcon: Icons.image_outlined,
                    onTap: session.before != null ? onBind : null,
                    onLongPress: session.before != null ? onBind : null,
                    onDelete: onDismissBefore,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _PairSlot(
                    label: '후',
                    item: session.after,
                    emptyIcon: Icons.add_a_photo_outlined,
                    showPlus: session.after == null,
                    onTap: session.after != null ? onBind : onShootAfter,
                    onLongPress: session.after != null ? onBind : null,
                    onDelete: onDismissAfter,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PairSlot extends StatelessWidget {
  const _PairSlot({
    required this.label,
    required this.emptyIcon,
    this.item,
    this.showPlus = false,
    this.onTap,
    this.onLongPress,
    this.onDelete,
  });

  final String label;
  final ShootInboxItem? item;
  final IconData emptyIcon;
  final bool showPlus;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final filled = item != null && item!.imageUrl.isNotEmpty;
    final stamp = formatShootInboxStamp(item?.createdAt);

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: Material(
            color: filled ? Colors.transparent : SoriTokens.surfaceOverlay,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: filled
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned.fill(
                          child: InkWell(
                            onTap: onTap,
                            onLongPress: onLongPress,
                            child: Image.network(
                              item!.imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (_, _, _) => const Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        ),
                        if (stamp.isNotEmpty)
                          Positioned(
                            left: 6,
                            top: 6,
                            right: 36,
                            child: IgnorePointer(
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: _StampBadge(text: stamp),
                              ),
                            ),
                          ),
                        if (onDelete != null)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: _SlotDeleteButton(onTap: onDelete!),
                          ),
                      ],
                    )
                  : InkWell(
                      onTap: onTap,
                      onLongPress: onLongPress,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              emptyIcon,
                              size: 28,
                              color: SoriTokens.textTertiary,
                            ),
                            if (showPlus) ...[
                              const SizedBox(height: 4),
                              Icon(
                                Icons.add_rounded,
                                size: 18,
                                color:
                                    SoriTokens.primary.withValues(alpha: 0.9),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: SoriTokens.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// 사진 위 촬영 시각 — 밝고 어두운 배경 모두에서 읽히게 어두운 칩.
class _StampBadge extends StatelessWidget {
  const _StampBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _SlotDeleteButton extends StatelessWidget {
  const _SlotDeleteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 28,
          height: 28,
          child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({
    required this.customer,
    required this.onClear,
    required this.onBefore,
    required this.onAfter,
  });

  final Customer customer;
  final VoidCallback onClear;
  final VoidCallback onBefore;
  final VoidCallback onAfter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SoriTokens.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: SoriTokens.primarySoft,
                child: Text(
                  customer.name.isNotEmpty
                      ? customer.name.characters.first
                      : '?',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  customer.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onBefore,
                  icon: const Icon(Icons.camera_enhance_outlined),
                  label: const Text(
                    '전 촬영',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: SoriTokens.brand,
                    foregroundColor: SoriTokens.onBrand,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAfter,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text(
                    '후 촬영',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SoriTokens.brand,
                    side: const BorderSide(color: SoriTokens.brand),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
