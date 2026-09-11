import 'package:flutter/material.dart';

import '../../../theme/sori_tokens.dart';
import '../../../widgets/sori_pressable.dart';

/// 사장 책상 오늘 — 저강도 경영 Peek 최대 1 (인사이트≠업무 큐).
/// 금액·Payment를 발명하지 않는다. 경영 탭 진입만.
class MyTodayBizPeekCard extends StatelessWidget {
  const MyTodayBizPeekCard({
    super.key,
    required this.onOpenBiz,
  });

  final VoidCallback onOpenBiz;

  @override
  Widget build(BuildContext context) {
    return SoriPressable(
      semanticLabel: '경영에서 이번 달 흐름 보기',
      onTap: onOpenBiz,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        decoration: BoxDecoration(
          color: SoriTokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SoriTokens.inputBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SoriTokens.brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.trending_up_rounded,
                color: SoriTokens.brand,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이번 달 흐름',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '경영에서 보기',
                    style: TextStyle(
                      fontSize: 12,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: SoriTokens.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
