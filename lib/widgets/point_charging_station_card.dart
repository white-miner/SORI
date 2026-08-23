import 'package:flutter/material.dart';

import '../models/sori_point_wallet.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

/// 마이페이지 · 포인트 충전소 (IAP 브릿지).
class PointChargingStationCard extends StatefulWidget {
  const PointChargingStationCard({super.key, required this.store});

  final SoriStore store;

  @override
  State<PointChargingStationCard> createState() =>
      _PointChargingStationCardState();
}

class _PointChargingStationCardState extends State<PointChargingStationCard> {
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    await widget.store.refreshPointWallet();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _buy(PointPack pack) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SoriTokens.surface,
        title: const Text('포인트 충전'),
        content: Text(
          '${pack.points}P를 ${pack.priceLabel}에 충전할까요?\n'
          '(IAP 연동 준비 — 지금은 테스트 충전입니다)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('충전'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.store.purchaseSoriPoints(
        amount: pack.points,
        sku: pack.sku,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${pack.points}P가 유료 포인트로 충전되었습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('충전에 실패했습니다. 마이그레이션 053 적용 여부를 확인해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final rev = s.length - i;
      buf.write(s[i]);
      if (rev > 1 && rev % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.store.pointWallet;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SoriTokens.outlinePurple),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '포인트 충전소',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: _loading || _busy ? null : _reload,
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
          const Text(
            '활동 포인트와 유료 포인트를 분리 보관합니다',
            style: TextStyle(
              fontSize: 12,
              color: SoriTokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _Bal(
                    label: '활동(무료)',
                    value: '${_fmt(w.freeBalance)}P',
                  ),
                ),
                Expanded(
                  child: _Bal(
                    label: '유료',
                    value: '${_fmt(w.paidBalance)}P',
                  ),
                ),
                Expanded(
                  child: _Bal(
                    label: '합계',
                    value: '${_fmt(w.totalBalance)}P',
                    accent: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              '즉시 충전 패키지',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 8),
            ...PointPack.catalog.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _buy(p),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC4B5FD),
                    side: BorderSide(
                      color: SoriTokens.primary.withValues(alpha: 0.45),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_fmt(p.points)}P',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (p.badge.isNotEmpty) ...[
                        Text(
                          p.badge,
                          style: const TextStyle(
                            fontSize: 11,
                            color: SoriTokens.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        p.priceLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.store.pointTransactions.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                '최근 원장',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 6),
              ...widget.store.pointTransactions.take(4).map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.note.trim().isEmpty ? t.kind : t.note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Text(
                            '${t.amount > 0 ? '+' : ''}${t.amount}P',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: t.amount >= 0
                                  ? SoriTokens.primary
                                  : const Color(0xFFF87171),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Bal extends StatelessWidget {
  const _Bal({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: SoriTokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: accent ? 15 : 13,
            fontWeight: FontWeight.w900,
            color: accent ? SoriTokens.primary : Colors.white,
          ),
        ),
      ],
    );
  }
}
