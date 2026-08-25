import 'dart:async';

import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../models/shoot_inbox_item.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'smart_guide_camera_page.dart';

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
  String? _tempSessionToken;
  String? _tempSessionBeforeUrl;

  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(store.refreshShootInbox());
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

  Future<void> _shootExisting({
    required Customer customer,
    required GuideCameraKind kind,
    CustomerChart? targetChart,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final chart = targetChart ??
          await store.ensureTodayShootChart(customerId: customer.id);
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.kind == GuideCameraKind.before
                ? '${customer.name} · ${chart.visitNumber}회 Before 저장'
                : '${customer.name} · ${chart.visitNumber}회 After 저장',
          ),
          backgroundColor: SoriTokens.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('촬영 저장 실패: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shootUnbound({required GuideCameraKind kind}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      _tempSessionToken ??=
          'sess-${DateTime.now().millisecondsSinceEpoch}';
      final ghost = kind == GuideCameraKind.after ? _tempSessionBeforeUrl : null;

      final result = await SmartGuideCameraPage.open(
        context,
        shopId: store.shop.id,
        customerId: 'unbound',
        kind: kind,
        ghostBeforeUrl: ghost,
      );
      if (!mounted || result == null) return;

      final labelCtrl = TextEditingController(
        text: kind == GuideCameraKind.before ? '신규' : '신규 After',
      );
      final label = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: SoriTokens.surfaceElevated,
          title: const Text(
            '임시 라벨',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: labelCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: '예: 1번 베드, 김○○',
              hintStyle: TextStyle(color: SoriTokens.textQuaternary),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('건너뛰기'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, labelCtrl.text.trim()),
              child: const Text(
                '저장',
                style: TextStyle(
                  color: SoriTokens.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
      labelCtrl.dispose();

      await store.enqueueShootInboxItem(
        ShootInboxItem(
          id: 'inbox-${DateTime.now().microsecondsSinceEpoch}',
          shopId: store.shop.id,
          kind: result.kind == GuideCameraKind.before ? 'before' : 'after',
          imageUrl: result.url,
          label: (label ?? '').trim().isEmpty ? '미등록' : label!.trim(),
          sessionToken: _tempSessionToken!,
          createdAt: DateTime.now(),
          ghostBeforeUrl: ghost,
        ),
      );
      if (result.kind == GuideCameraKind.before) {
        _tempSessionBeforeUrl = result.url;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('미연결 큐에 저장했어요. 나중에 고객에게 연결하세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('임시 촬영 실패: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bindInbox(ShootInboxItem item) async {
    final customer = await _pickCustomerForBind();
    if (customer == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await store.bindShootInboxToCustomer(
        inboxId: item.id,
        customerId: customer.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${customer.name} 차트에 연결했어요'),
          backgroundColor: SoriTokens.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('연결 실패: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    final inbox = store.shootInbox;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: SoriTokens.background,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 100 + bottom),
              children: [
                const Text(
                  '촬영',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '고객 선택 → Before. 케어가 끝나면 After 대기 칩을 탭하세요. 순서는 상관 없습니다.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: SoriTokens.textSecondary,
                  ),
                ),
                if (waiting.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'After 대기 · ${waiting.length}',
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
                if (inbox.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    '미연결 · ${inbox.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in inbox)
                    _InboxTile(
                      item: item,
                      onBind: () => _bindInbox(item),
                      onDismiss: () =>
                          unawaited(store.dismissShootInboxItem(item.id)),
                    ),
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
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _shootUnbound(kind: GuideCameraKind.before),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text(
                    '신규 · 임시 Before 촬영',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy || _tempSessionBeforeUrl == null
                      ? null
                      : () => _shootUnbound(kind: GuideCameraKind.after),
                  child: const Text(
                    '같은 임시 세션 After 촬영',
                    style: TextStyle(fontWeight: FontWeight.w700),
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

class _InboxTile extends StatelessWidget {
  const _InboxTile({
    required this.item,
    required this.onBind,
    required this.onDismiss,
  });

  final ShootInboxItem item;
  final VoidCallback onBind;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: SoriTokens.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            item.imageUrl,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 48,
              height: 48,
              color: SoriTokens.surfaceOverlay,
              child: const Icon(Icons.image_not_supported_outlined),
            ),
          ),
        ),
        title: Text(
          '${item.label} · ${item.isBefore ? 'Before' : 'After'}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text(
          '고객 미연결',
          style: TextStyle(fontSize: 12, color: SoriTokens.textTertiary),
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            TextButton(
              onPressed: onBind,
              child: const Text(
                '연결',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: SoriTokens.primary,
                ),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
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
                    'Before',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: SoriTokens.primary,
                    foregroundColor: Colors.black,
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
                    'After',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SoriTokens.textPrimary,
                    side: const BorderSide(color: SoriTokens.border),
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
