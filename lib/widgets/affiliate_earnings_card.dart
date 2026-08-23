import 'package:flutter/material.dart';

import '../models/affiliate_earnings.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

/// 마이페이지 · 제휴 수익 정산 현황 + Admin confirmed→paid.
class AffiliateEarningsCard extends StatefulWidget {
  const AffiliateEarningsCard({super.key, required this.store});

  final SoriStore store;

  @override
  State<AffiliateEarningsCard> createState() => _AffiliateEarningsCardState();
}

class _AffiliateEarningsCardState extends State<AffiliateEarningsCard> {
  AffiliateEarningsSummary? _summary;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = await widget.store.loadAffiliateEarnings();
    if (!mounted) return;
    setState(() {
      _summary = s;
      _loading = false;
    });
  }

  Future<void> _settle(AffiliateConversion c, String toStatus) async {
    setState(() => _busy = true);
    final ok = await widget.store.settleAffiliateConversion(
      conversionId: c.id,
      toStatus: toStatus,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok == null
              ? '정산 상태 변경에 실패했습니다'
              : toStatus == 'paid'
                  ? '지급 완료로 반영되었습니다'
                  : '전환이 확정되었습니다',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _load();
  }

  Future<void> _addDemoConversion() async {
    setState(() => _busy = true);
    await widget.store.recordAffiliateConversion(
      commissionAmount: 5000,
      orderRef: 'MANUAL-${DateTime.now().millisecondsSinceEpoch % 100000}',
      grossAmount: 50000,
      note: '관리자 수동 전환 등록',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
  }

  static String _won(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final rev = s.length - i;
      buf.write(s[i]);
      if (rev > 1 && rev % 3 == 1) buf.write(',');
    }
    return '${buf.toString()}원';
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary ?? const AffiliateEarningsSummary();
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
                  '내 제휴 수익 정산 현황',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loading || _busy ? null : _load,
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '클릭 예상 수수료 + 구매 전환(confirmed→paid) 원장',
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
                  child: _Metric(
                    label: '클릭',
                    value: '${s.clickCount}',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: '예상 적립',
                    value: _won(s.totalEarned),
                    accent: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: '대기',
                    value: _won(s.pendingAmount),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: '확정',
                    value: _won(s.confirmedAmount),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: '지급',
                    value: _won(s.paidAmount),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '전환 정산 (Admin)',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _addDemoConversion,
                  child: const Text('전환 등록'),
                ),
              ],
            ),
            if (s.recentConversions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '아직 구매 전환이 없습니다. 전환 등록 후 확정·지급하세요.',
                  style: TextStyle(
                    fontSize: 12,
                    color: SoriTokens.textSecondary,
                  ),
                ),
              )
            else
              ...s.recentConversions.take(6).map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.orderRef.trim().isEmpty
                                      ? '전환 ${c.id.substring(0, c.id.length.clamp(0, 8))}'
                                      : c.orderRef,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${c.status} · ${_won(c.commissionAmount)}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: SoriTokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (c.status == 'pending')
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _settle(c, 'confirmed'),
                              child: const Text('확정'),
                            ),
                          if (c.status == 'confirmed')
                            TextButton(
                              onPressed:
                                  _busy ? null : () => _settle(c, 'paid'),
                              child: const Text('지급'),
                            ),
                        ],
                      ),
                    ),
                  ),
            if (s.recentCommissions.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                '최근 수수료 원장',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 8),
              ...s.recentCommissions.take(5).map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.linkLabel.trim().isEmpty
                                  ? (c.destinationUrl.isEmpty
                                      ? '제휴 클릭'
                                      : c.destinationUrl)
                                  : c.linkLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                          Text(
                            '${c.status} · ${_won(c.amount)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: SoriTokens.primary,
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

class _Metric extends StatelessWidget {
  const _Metric({
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
            fontSize: accent ? 16 : 14,
            fontWeight: FontWeight.w900,
            color: accent ? SoriTokens.primary : Colors.white,
          ),
        ),
      ],
    );
  }
}
