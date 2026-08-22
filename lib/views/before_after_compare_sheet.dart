import 'package:flutter/material.dart';

import '../models/customer_chart.dart';
import '../theme/sori_tokens.dart';
import '../widgets/before_after_slider.dart';
import 'my_app.dart';

/// 회차 단위 사진 슬롯 (chart_records before/after + visit_number SSOT).
class VisitPhotoSlot {
  const VisitPhotoSlot({
    required this.chartId,
    required this.visitNumber,
    required this.kind,
    required this.url,
    required this.careName,
  });

  final String chartId;
  final int visitNumber;
  final String kind; // before | after
  final String url;
  final String careName;

  String get key => '$chartId|$kind';

  String get label {
    final care = careName.trim().isEmpty ? '' : ' · $careName';
    final side = kind == 'before' ? 'Before' : 'After';
    return '$visitNumber회차 $side$care';
  }

  String get shortLabel => '$visitNumber회차 · ${kind == 'before' ? 'B' : 'A'}';
}

/// 고객 차트 B/A 사진 — 회차 선택 후 슬라이더/나란히 비교.
Future<void> showBeforeAfterCompareSheet({
  required BuildContext context,
  required List<CustomerChart> charts,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _BeforeAfterCompareSheet(charts: charts),
  );
}

List<VisitPhotoSlot> buildVisitPhotoSlots(List<CustomerChart> charts) {
  final slots = <VisitPhotoSlot>[];
  final sorted = List<CustomerChart>.from(charts)
    ..sort((a, b) => a.visitNumber.compareTo(b.visitNumber));
  for (final chart in sorted) {
    final before = chart.beforeImageUrl?.trim();
    final after = chart.afterImageUrl?.trim();
    if (before != null && before.isNotEmpty) {
      slots.add(
        VisitPhotoSlot(
          chartId: chart.id,
          visitNumber: chart.visitNumber,
          kind: 'before',
          url: before,
          careName: chart.careName,
        ),
      );
    }
    if (after != null && after.isNotEmpty) {
      slots.add(
        VisitPhotoSlot(
          chartId: chart.id,
          visitNumber: chart.visitNumber,
          kind: 'after',
          url: after,
          careName: chart.careName,
        ),
      );
    }
  }
  return slots;
}

class _BeforeAfterCompareSheet extends StatefulWidget {
  const _BeforeAfterCompareSheet({required this.charts});

  final List<CustomerChart> charts;

  @override
  State<_BeforeAfterCompareSheet> createState() =>
      _BeforeAfterCompareSheetState();
}

class _BeforeAfterCompareSheetState extends State<_BeforeAfterCompareSheet> {
  late final List<VisitPhotoSlot> _slots;
  VisitPhotoSlot? _left;
  VisitPhotoSlot? _right;
  bool _useSlider = true;

  @override
  void initState() {
    super.initState();
    _slots = buildVisitPhotoSlots(widget.charts);
    if (_slots.isNotEmpty) {
      _left = _slots.first;
      _right = _slots.length > 1 ? _slots.last : _slots.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final empty = _slots.isEmpty;
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: empty ? 0.42 : 0.88,
        minChildSize: 0.35,
        maxChildSize: 0.96,
        builder: (_, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: SoriTokens.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '관리 경과 비교 (B/A)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('닫기'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: empty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            '비교할 회차 사진이 아직 없습니다.\n차트에 Before/After를 첨부하면 회차별로 선택할 수 있어요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              height: 1.4,
                              color: SoriTokens.textSecondary,
                            ),
                          ),
                        ),
                      )
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                        children: [
                          const Text(
                            '좌·우에서 회차 사진을 고른 뒤 비교하세요. 사진은 chart_records의 before/after + visit_number와 동기화됩니다.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: SoriTokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _VisitPhotoPicker(
                                  title: '왼쪽',
                                  selected: _left,
                                  options: _slots,
                                  onChanged: (v) => setState(() => _left = v),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _VisitPhotoPicker(
                                  title: '오른쪽',
                                  selected: _right,
                                  options: _slots,
                                  onChanged: (v) => setState(() => _right = v),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: true,
                                label: Text('슬라이더'),
                                icon: Icon(Icons.compare_arrows, size: 16),
                              ),
                              ButtonSegment(
                                value: false,
                                label: Text('나란히'),
                                icon: Icon(Icons.view_column_outlined, size: 16),
                              ),
                            ],
                            selected: {_useSlider},
                            onSelectionChanged: (s) =>
                                setState(() => _useSlider = s.first),
                          ),
                          const SizedBox(height: 14),
                          if (_left != null && _right != null) ...[
                            Text(
                              '${_left!.shortLabel}  ↔  ${_right!.shortLabel}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_useSlider)
                              BeforeAfterSlider(
                                height: 280,
                                before: ChartImagePane(
                                  url: _left!.url,
                                  fallbackLabel: _left!.shortLabel,
                                  tone: MyApp.soriPurple,
                                ),
                                after: ChartImagePane(
                                  url: _right!.url,
                                  fallbackLabel: _right!.shortLabel,
                                  tone: Colors.green.shade700,
                                ),
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text(
                                          _left!.label,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        SizedBox(
                                          height: 220,
                                          child: ChartImagePane(
                                            url: _left!.url,
                                            fallbackLabel: _left!.shortLabel,
                                            tone: MyApp.soriPurple,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text(
                                          _right!.label,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        SizedBox(
                                          height: 220,
                                          child: ChartImagePane(
                                            url: _right!.url,
                                            fallbackLabel: _right!.shortLabel,
                                            tone: Colors.green.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VisitPhotoPicker extends StatelessWidget {
  const _VisitPhotoPicker({
    required this.title,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final VisitPhotoSlot? selected;
  final List<VisitPhotoSlot> options;
  final ValueChanged<VisitPhotoSlot> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: SoriTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        InputDecorator(
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selected?.key,
              isExpanded: true,
              items: [
                for (final slot in options)
                  DropdownMenuItem(
                    value: slot.key,
                    child: Text(
                      slot.shortLabel,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
              onChanged: (key) {
                if (key == null) return;
                final match = options.where((s) => s.key == key);
                if (match.isNotEmpty) onChanged(match.first);
              },
            ),
          ),
        ),
        if (options.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, index) {
                final slot = options[index];
                final selectedNow = selected?.key == slot.key;
                return ChoiceChip(
                  label: Text(slot.shortLabel, style: const TextStyle(fontSize: 11)),
                  selected: selectedNow,
                  onSelected: (_) => onChanged(slot),
                  selectedColor: MyApp.soriPurple.withValues(alpha: 0.18),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
