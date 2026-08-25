import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/sori_point_wallet.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

/// 마이페이지 · SORI Echo 카드 (E 단위, 출금 불가, 1E=₩100).
/// 정산금과 합산 표시 금지.
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

  static const _accent = SoriTokens.premium;
  static const _accentSoft = SoriTokens.premiumSoft;

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
        title: const Text('Echo 충전'),
        content: Text(
          '${pack.echo} Echo를 ${pack.priceLabel}에 충전할까요?\n'
          '1 Echo = 100원 · 출금 불가 · 앱 내 소비 전용\n'
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
          content: Text('${pack.echo} Echo가 유료 잔액으로 충전되었습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('충전에 실패했습니다. 마이그레이션 053~056 적용 여부를 확인해 주세요.'),
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
        border: Border.all(color: _accent.withValues(alpha: 0.55)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1428), Color(0xFF18181B)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.diamond_rounded,
                  color: _accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SORI Echo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '1 Echo = 100원 · 출금 불가 (E)',
                      style: TextStyle(
                        fontSize: 11,
                        color: SoriTokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loading || _busy ? null : _reload,
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
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
            Text(
              '${_fmt(w.pointTotal)}E',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: _accent,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '≈ ₩${_fmt(w.echoKrwValue)} · 1 Echo = 100원',
              style: const TextStyle(
                fontSize: 12,
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Bal(
                    label: '활동(Free)',
                    value: '${_fmt(w.freeBalance)}E',
                  ),
                ),
                Expanded(
                  child: _Bal(
                    label: '유료(Paid)',
                    value: '${_fmt(w.paidBalance)}E',
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
                    foregroundColor: _accent,
                    side: BorderSide(color: _accent.withValues(alpha: 0.45)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_fmt(p.echo)}E',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (p.badge.isNotEmpty) ...[
                        Text(
                          p.badge,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _accent,
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
                '최근 Echo 원장',
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
                            '${t.amount > 0 ? '+' : ''}${t.amount}E',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: t.amount >= 0
                                  ? _accent
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
  const _Bal({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// 마이페이지 · 정산금 카드 (₩ 단위, 출금 가능).
/// [계좌로 환전하기] 버튼은 이 카드에만 배치.
class SettlementWalletCard extends StatefulWidget {
  const SettlementWalletCard({super.key, required this.store});

  final SoriStore store;

  @override
  State<SettlementWalletCard> createState() => _SettlementWalletCardState();
}

class _SettlementWalletCardState extends State<SettlementWalletCard> {
  bool _loading = true;
  bool _busy = false;

  static const _accent = SoriTokens.primary;
  static const _accentDeep = SoriTokens.primaryLight;
  static const _accentSoft = Color(0x33047857);

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

  Future<void> _withdraw() async {
    final w = widget.store.pointWallet;
    if (w.settlementBalance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('출금 가능한 정산금이 없습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final controller = TextEditingController(
      text: w.settlementBalance.toString(),
    );
    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SoriTokens.surface,
        title: const Text('계좌로 환전하기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '출금 가능 ₩${_fmt(w.settlementBalance)}\n'
              'Echo는 환전할 수 없습니다. 정산금만 계좌로 이체됩니다.',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '환전 금액 (원)',
                prefixText: '₩ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accentDeep),
            onPressed: () {
              final n = int.tryParse(controller.text.trim()) ?? 0;
              Navigator.pop(ctx, n);
            },
            child: const Text('요청'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || amount <= 0 || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.store.requestSettlementWithdraw(amount: amount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('₩${_fmt(amount)} 환전 요청이 접수되었습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('환전 요청에 실패했습니다. 마이그레이션 054 적용 여부를 확인해 주세요.'),
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
        border: Border.all(color: _accent.withValues(alpha: 0.5)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1F1A), Color(0xFF18181B)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: _accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SORI 정산금',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '실거래 정산 · 계좌 환전 가능 (₩)',
                      style: TextStyle(
                        fontSize: 11,
                        color: SoriTokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loading || _busy ? null : _reload,
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
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
            Text(
              '₩${_fmt(w.settlementBalance)}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: _accent,
                letterSpacing: -0.5,
              ),
            ),
            if (w.settlementPending > 0) ...[
              const SizedBox(height: 6),
              Text(
                '출금 대기 ₩${_fmt(w.settlementPending)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: SoriTokens.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _busy ? null : _withdraw,
              style: FilledButton.styleFrom(
                backgroundColor: _accentDeep,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.south_west_rounded, size: 18),
              label: const Text(
                '계좌로 환전하기',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (widget.store.settlementTransactions.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                '최근 정산 원장',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 6),
              ...widget.store.settlementTransactions.take(4).map(
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
                            '${t.amount > 0 ? '+' : ''}₩${_fmt(t.amount.abs())}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: t.amount >= 0
                                  ? _accent
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
