import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_bottom_sheet.dart';

/// 원장 Review 탭 — 고객 차트에 연결된 실리뷰 등록.
Future<void> showShopReviewComposeSheet(
  BuildContext context,
  SoriStore store,
) async {
  final candidates = <({Customer customer, CustomerChart chart})>[];
  for (final c in store.customers) {
    CustomerChart? latest;
    for (final ch in store.charts) {
      if (ch.customerId != c.id) continue;
      if (latest == null) {
        latest = ch;
        continue;
      }
      final a = ch.createdAt ?? ch.visitCheckedAt ?? DateTime(1970);
      final b = latest.createdAt ?? latest.visitCheckedAt ?? DateTime(1970);
      if (a.isAfter(b)) latest = ch;
    }
    if (latest != null) {
      candidates.add((customer: c, chart: latest));
    }
  }

  if (candidates.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('리뷰를 등록하려면 차트(케어)가 있는 고객이 필요해요'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  var selected = candidates.first;
  final textCtrl = TextEditingController();
  var rating = 5;

  final ok = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              14,
              16,
              16 + soriSheetBottomPadding(ctx),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '리뷰 작성',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selected.chart.id,
                    decoration: const InputDecoration(labelText: '고객 · 차트'),
                    items: [
                      for (final item in candidates)
                        DropdownMenuItem(
                          value: item.chart.id,
                          child: Text(
                            '${item.customer.name} · ${item.chart.careName.trim().isEmpty ? '케어' : item.chart.careName}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      if (id == null) return;
                      selected = candidates.firstWhere((e) => e.chart.id == id);
                      setSheet(() {});
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '별점',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      return IconButton(
                        onPressed: () => setSheet(() => rating = star),
                        icon: Icon(
                          star <= rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: SoriTokens.warningText,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: textCtrl,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: '리뷰 내용',
                      hintText: '고객이 남긴 후기를 기록해 주세요',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: SoriTokens.primary,
                    ),
                    child: const Text('등록'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  if (ok != true) return;
  final text = textCtrl.text.trim();
  if (text.isEmpty) return;

  try {
    await store.publishShopReview(
      chartId: selected.chart.id,
      customerId: selected.customer.id,
      text: text,
      rating: rating,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('리뷰가 등록되었어요'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: SoriTokens.primary,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('등록 실패: $e'),
        backgroundColor: SoriTokens.systemRed,
      ),
    );
  }
}
