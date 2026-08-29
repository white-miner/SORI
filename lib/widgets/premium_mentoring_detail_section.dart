import 'package:flutter/material.dart';

import '../models/chart_mentoring_meta.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'insufficient_points_sheet.dart';
import 'mentoring_request_sheet.dart';

/// Case detail — Premium Mentoring unlock / purchased body.
class PremiumMentoringDetailSection extends StatefulWidget {
  const PremiumMentoringDetailSection({
    super.key,
    required this.store,
    required this.chartId,
    this.sectionKey,
    this.initialMeta,
    this.onReady,
  });

  final SoriStore store;
  final String chartId;
  final GlobalKey? sectionKey;
  final ChartMentoringMeta? initialMeta;
  final VoidCallback? onReady;

  @override
  State<PremiumMentoringDetailSection> createState() =>
      _PremiumMentoringDetailSectionState();
}

class _PremiumMentoringDetailSectionState
    extends State<PremiumMentoringDetailSection> {
  ChartMentoringDetail? _detail;
  bool _loading = true;
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final detail = await widget.store.loadMentoringForChart(widget.chartId);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _loading = false;
    });
    if (detail.exists && detail.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onReady?.call();
      });
    }
  }

  Future<void> _purchase() async {
    final detail = _detail;
    if (detail == null || !detail.canPurchase || _purchasing) return;
    setState(() => _purchasing = true);
    try {
      await widget.store.refreshCustomerEchoWallet();
      final bal = widget.store.customerEchoWallet.pointTotal;
      if (bal < detail.priceEcho) {
        final charged = await showInsufficientPointsSheet(
          context,
          store: widget.store,
          need: detail.priceEcho,
          have: bal,
          productLabel: 'Premium Mentoring',
          useCustomerWallet: true,
        );
        if (charged != true || !mounted) {
          setState(() => _purchasing = false);
          return;
        }
      }
      final unlocked =
          await widget.store.purchaseMentoringUnlock(detail.id);
      if (!mounted) return;
      setState(() {
        _detail = unlocked;
        _purchasing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Premium Mentoring이 잠금 해제되었습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _purchasing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('구매에 실패했습니다: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }

    final detail = _detail;
    if (detail == null || !detail.exists || !detail.isActive) {
      return const SizedBox.shrink();
    }

    final unlocked = detail.isUnlocked;
    final body = detail.bodyLocked?.trim() ?? '';

    return Container(
      key: widget.sectionKey,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x0F4338CA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x334338CA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PremiumMentoringFeedChip(
                priceEcho: detail.priceEcho,
                compact: true,
              ),
              const Spacer(),
              if (detail.purchaseCount > 0)
                Text(
                  '${detail.purchaseCount} unlocks',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: SoriTokens.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            detail.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: SoriTokens.textPrimary,
            ),
          ),
          if (detail.previewTeaser.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              detail.previewTeaser.trim(),
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: SoriTokens.textSecondary,
              ),
            ),
          ],
          if (unlocked && body.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              body,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: SoriTokens.textPrimary,
              ),
            ),
          ] else if (!unlocked) ...[
            const SizedBox(height: 12),
            const Text(
              '원장 임상 노트 전문은 Echo로 잠금 해제 후 확인할 수 있어요.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: SoriTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: detail.canPurchase && !_purchasing ? _purchase : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4338CA),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: _purchasing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_open_rounded, size: 18),
              label: Text(
                'Unlock · ${detail.priceEcho} E',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
