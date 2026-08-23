import 'package:flutter/material.dart';

import '../models/sori_point_wallet.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

/// 잔액 부족 시 원탭 IAP 스텁 바텀시트.
/// 부족분을 넘는 최소 팩을 추천하고, 충전 후 [onCharged]로 재시도한다.
Future<bool> showInsufficientPointsSheet(
  BuildContext context, {
  required SoriStore store,
  required int need,
  int? have,
  String productLabel = '부스터',
}) async {
  final balance = have ?? store.pointWallet.pointTotal;
  final gap = (need - balance).clamp(1, 1 << 30);
  final pack = _recommendPack(gap);

  final charged = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      var busy = false;
      return StatefulBuilder(
        builder: (ctx, setModal) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                16 + MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: SoriTokens.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '포인트가 부족해요',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$productLabel를 바로 적용하려면 ${gap}P가 더 필요해요.\n'
                    '보유 ${ _fmt(balance)}P · 필요 ${_fmt(need)}P\n\n'
                    '${pack.points}P 충전팩(${pack.priceLabel})을 구매할까요?',
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: SoriTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setModal(() => busy = true);
                            try {
                              await store.purchaseSoriPoints(
                                amount: pack.points,
                                sku: pack.sku,
                              );
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (_) {
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('충전에 실패했습니다. 잠시 후 다시 시도해 주세요.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              setModal(() => busy = false);
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: SoriTokens.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            '${_fmt(pack.points)}P 충전하고 계속 · ${pack.priceLabel}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: busy ? null : () => Navigator.pop(ctx, false),
                    child: const Text('나중에'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  return charged == true;
}

PointPack _recommendPack(int gap) {
  for (final p in PointPack.catalog) {
    if (p.points >= gap) return p;
  }
  return PointPack.catalog.last;
}

String _fmt(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final rev = s.length - i;
    buf.write(s[i]);
    if (rev > 1 && rev % 3 == 1) buf.write(',');
  }
  return buf.toString();
}
