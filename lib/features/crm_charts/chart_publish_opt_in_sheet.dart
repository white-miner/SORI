import 'package:flutter/material.dart';

import '../../crm_kernel/theme/crm_calm_glass_tokens.dart';
import '../../models/customer_chart.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../utils/consent_publish_gate.dart';

/// PO 확정: 차트 저장 후 Opt-in 커뮤니티 게시 확인.
Future<bool> showChartPublishOptInSheet(
  BuildContext context, {
  required SoriStore store,
  required CustomerChart chart,
}) async {
  final gate = canPublishBa(chart);
  if (!gate.allowsPublish) return false;

  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.viewInsetsOf(ctx).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: SoriTokens.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 20),
          Icon(
            Icons.auto_awesome_rounded,
            size: 40,
            color: CrmCalmGlassTokens.care,
          ),
          const SizedBox(height: 16),
          const Text(
            '이 케이스를 커뮤니티에 자랑할까요?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '고객 정보는 마스킹되고 Before/After가 홈·탐색에 노출됩니다. '
            '언제든 게시물에서 숨길 수 있어요.',
            textAlign: TextAlign.center,
            style: CrmCalmGlassTokens.captionCalm.copyWith(
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('나중에'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: CrmCalmGlassTokens.care,
                  ),
                  child: const Text('게시하기'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  if (result != true || !context.mounted) return false;

  try {
    await store.publishChartCaseToCommunity(chart);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('커뮤니티에 게시되었습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('게시에 실패했습니다. 나중에 다시 시도해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }
}
