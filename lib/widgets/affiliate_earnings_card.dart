import 'package:flutter/material.dart';

import '../models/affiliate_earnings.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

/// 마이페이지 · 제휴 수익 정산 현황.
class AffiliateEarningsCard extends StatefulWidget {
  const AffiliateEarningsCard({super.key, required this.store});

  final SoriStore store;

  @override
  State<AffiliateEarningsCard> createState() => _AffiliateEarningsCardState();
}

class _AffiliateEarningsCardState extends State<AffiliateEarningsCard> {
  AffiliateEarningsSummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await widget.store.loadAffiliateEarnings();
    if (!mounted) return;
    setState(() {
      _summary = s;
      _loading = false;
    });
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
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '리뷰·핫스팟 외부 링크 클릭으로 적립된 예상 수수료',
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
            if (s.recentCommissions.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                '최근 적립',
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
                            _won(c.amount),
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
