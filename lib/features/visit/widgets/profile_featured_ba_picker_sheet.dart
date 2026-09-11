import 'package:flutter/material.dart';

import '../../../models/customer_chart.dart';
import '../../../theme/sori_tokens.dart';
import '../profile_showcase.dart';

/// 원장 전용 — 대표 B/A 최대 5 · 선택 순 = 표시 순.
Future<List<String>?> showProfileFeaturedBaPickerSheet({
  required BuildContext context,
  required List<CustomerChart> charts,
  required List<String> initialFeaturedIds,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return _ProfileFeaturedBaPickerBody(
        charts: charts,
        initialFeaturedIds: initialFeaturedIds,
      );
    },
  );
}

class _ProfileFeaturedBaPickerBody extends StatefulWidget {
  const _ProfileFeaturedBaPickerBody({
    required this.charts,
    required this.initialFeaturedIds,
  });

  final List<CustomerChart> charts;
  final List<String> initialFeaturedIds;

  @override
  State<_ProfileFeaturedBaPickerBody> createState() =>
      _ProfileFeaturedBaPickerBodyState();
}

class _ProfileFeaturedBaPickerBodyState
    extends State<_ProfileFeaturedBaPickerBody> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = ProfileShowcase.normalizeFeaturedIds(widget.initialFeaturedIds);
  }

  List<CustomerChart> get _eligible => widget.charts
      .where(ProfileShowcase.isShowcaseEligible)
      .toList(growable: false);

  List<CustomerChart> get _hiddenStale {
    final eligibleIds = _eligible.map((c) => c.id).toSet();
    final byId = {for (final c in widget.charts) c.id: c};
    final out = <CustomerChart>[];
    for (final id in widget.initialFeaturedIds) {
      if (eligibleIds.contains(id)) continue;
      final c = byId[id];
      if (c != null) out.add(c);
    }
    return out;
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected = ProfileShowcase.removeFeatured(_selected, id);
        return;
      }
      final next = ProfileShowcase.tryAddFeatured(_selected, id);
      if (next == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('대표 사례는 최대 5개까지 선택할 수 있어요'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      _selected = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final eligible = _eligible;
    final stale = _hiddenStale;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SoriTokens.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '대표 사례 관리',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '이 기기 로컬에만 저장 · ${_selected.length}/${ProfileShowcase.maxFeatured}',
            style: const TextStyle(
              fontSize: 12.5,
              color: SoriTokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (eligible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                '커뮤니티 공개·동의된 사례가 생기면 선택할 수 있어요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: SoriTokens.textSecondary,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: eligible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final c = eligible[i];
                  final on = _selected.contains(c.id);
                  final care =
                      c.careName.trim().isEmpty ? '관리 케어' : c.careName.trim();
                  final order = on ? _selected.indexOf(c.id) + 1 : null;
                  return CheckboxListTile(
                    value: on,
                    onChanged: (_) => _toggle(c.id),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      care,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: order == null
                        ? null
                        : Text(
                            '표시 순서 $order',
                            style: const TextStyle(
                              fontSize: 12,
                              color: SoriTokens.textSecondary,
                            ),
                          ),
                  );
                },
              ),
            ),
          if (stale.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '현재 공개 조건을 충족하지 않아 숨겨진 사례 ${stale.length}건',
              style: const TextStyle(
                fontSize: 12,
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              ProfileShowcase.normalizeFeaturedIds(_selected),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: SoriTokens.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              '저장',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
