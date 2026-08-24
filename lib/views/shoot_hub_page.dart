import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'smart_guide_camera_page.dart';

/// 원장 GNB 중앙 「촬영」허브 — C0: 고객 선택 + 가이드 카메라 진입.
/// C1+ 에서 오늘 회차 자동생성·케어중 트레이를 확장한다.
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

  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
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

  /// Before만 있고 After가 비어 있는 최근 차트 → After 대기.
  List<({Customer customer, CustomerChart chart})> get _afterWaiting {
    final out = <({Customer customer, CustomerChart chart})>[];
    final now = DateTime.now();
    for (final c in store.customers) {
      for (final chart in store.chartsForCustomer(c.id)) {
        if (!chart.needsAfterPhoto) continue;
        final created = chart.createdAt;
        if (created != null && now.difference(created).inDays > 14) {
          continue;
        }
        out.add((customer: c, chart: chart));
      }
    }
    out.sort((a, b) {
      final ad = a.chart.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.chart.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return out.take(20).toList();
  }

  Future<void> _openGuide({
    required Customer customer,
    required GuideCameraKind kind,
    String? ghostBeforeUrl,
  }) async {
    final result = await SmartGuideCameraPage.open(
      context,
      shopId: store.shop.id,
      customerId: customer.id,
      kind: kind,
      ghostBeforeUrl: ghostBeforeUrl,
    );
    if (!mounted || result == null) return;

    // C0: 업로드는 카메라 페이지에서 완료. 최신 차트에 URL 반영 시도.
    final charts = store.chartsForCustomer(customer.id);
    CustomerChart? target;
    if (charts.isNotEmpty) {
      target = charts.first;
      for (final c in charts) {
        final a = c.createdAt;
        final b = target!.createdAt;
        if (a != null && (b == null || a.isAfter(b))) target = c;
      }
    }

    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kind == GuideCameraKind.before
                ? '사진은 저장됐어요. 차트에 연결하려면 고객 상세에서 회차를 열어 주세요.'
                : 'After 사진은 저장됐어요. 차트에서 회차를 확인해 주세요.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {});
      return;
    }

    try {
      if (result.kind == GuideCameraKind.before) {
        await store.updateCustomerChartFields(
          chartId: target.id,
          beforeImageUrl: result.url,
        );
      } else {
        await store.patchChartAfterImage(
          chartId: target.id,
          afterImageUrl: result.url,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.kind == GuideCameraKind.before
                ? '${customer.name} Before를 차트에 저장했어요'
                : '${customer.name} After를 차트에 저장했어요',
          ),
          backgroundColor: SoriTokens.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('차트 반영 실패: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _afterWaiting;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: SoriTokens.background,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 100 + bottom),
          children: [
            const Text(
              '촬영',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: SoriTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '고객을 고른 뒤 Before / After를 촬영합니다. 동시 케어는 아래 대기 칩을 탭하세요.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: SoriTokens.textSecondary,
              ),
            ),
            if (waiting.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'After 대기',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: waiting.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final row = waiting[i];
                    return _WaitingChip(
                      name: row.customer.name,
                      onTap: () {
                        setState(() => _selected = row.customer);
                        _openGuide(
                          customer: row.customer,
                          kind: GuideCameraKind.after,
                          ghostBeforeUrl: row.chart.beforeImageUrl,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 18),
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: SoriTokens.textPrimary),
              decoration: InputDecoration(
                hintText: '고객 이름·전화 검색',
                hintStyle: const TextStyle(color: SoriTokens.textQuaternary),
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
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SoriTokens.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SoriTokens.primary.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: SoriTokens.primarySoft,
                          child: Text(
                            _selected!.name.characters.first,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selected!.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _selected = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _openGuide(
                              customer: _selected!,
                              kind: GuideCameraKind.before,
                            ),
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
                            onPressed: () {
                              final charts =
                                  store.chartsForCustomer(_selected!.id);
                              CustomerChart? withBefore;
                              for (final c in charts) {
                                if (c.needsAfterPhoto) {
                                  withBefore = c;
                                  break;
                                }
                              }
                              if (withBefore == null) {
                                for (final c in charts) {
                                  if (c.hasBeforeImage) {
                                    withBefore = c;
                                    break;
                                  }
                                }
                              }
                              _openGuide(
                                customer: _selected!,
                                kind: GuideCameraKind.after,
                                ghostBeforeUrl: withBefore?.beforeImageUrl,
                              );
                            },
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
                    ? const Icon(Icons.check_circle, color: SoriTokens.primary)
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
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '신규·임시 촬영은 다음 단계에서 연결됩니다. 지금은 고객을 선택한 뒤 촬영해 주세요.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text(
                '신규 · 임시 촬영 (준비 중)',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingChip extends StatelessWidget {
  const _WaitingChip({required this.name, required this.onTap});

  final String name;
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
          width: 76,
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
              const SizedBox(height: 6),
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
            ],
          ),
        ),
      ),
    );
  }
}
