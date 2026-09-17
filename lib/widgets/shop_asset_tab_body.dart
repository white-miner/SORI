import 'package:flutter/material.dart';

import '../models/fan_supporter.dart';
import '../models/shop_assets.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'people_list_sheet.dart';
import 'supporter_interaction_statement_sheet.dart';

/// My Page · Asset 탭 — 플랫폼 내 비즈니스 자산 대시보드 (P0 shell).
class ShopAssetTabBody extends StatefulWidget {
  const ShopAssetTabBody({
    super.key,
    required this.store,
    required this.isOwner,
  });

  final SoriStore store;
  final bool isOwner;

  @override
  State<ShopAssetTabBody> createState() => _ShopAssetTabBodyState();
}

class _ShopAssetTabBodyState extends State<ShopAssetTabBody> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.store.refreshShopAssets();
      widget.store.refreshShopSupporterHeader();
    });
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOwner) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 40, color: SoriTokens.textSecondary),
              SizedBox(height: 12),
              Text(
                'Director only',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Asset dashboard is for shop directors.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: SoriTokens.textSecondary,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final snap = widget.store.shopAssets;
    final t1 = snap.tier1;
    final t2 = snap.tier2;
    final supporters = snap.supporterPreview.isNotEmpty
        ? snap.supporterPreview
        : FanSupporterEntry.ranked(
            widget.store.shopSupporterHeader.facepile,
          )
            .map(ShopAssetSupporterPreview.fromFanSupporter)
            .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        const Text(
          'Asset',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          'Platform business assets — interest before Echo.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: SoriTokens.textSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 20),
        const _SectionLabel('Interest assets'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Charts',
                value: _formatCount(t1.chartCountTotal),
                icon: Icons.folder_copy_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                label: 'B/A Views',
                value: _formatCount(t1.baViewTotal),
                icon: Icons.visibility_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                label: 'Bookmarks',
                value: _formatCount(t1.bookmarkTotal),
                icon: Icons.bookmark_outline_rounded,
              ),
            ),
          ],
        ),
        if (t1.baPublishedCount > 0) ...[
          const SizedBox(height: 8),
          Text(
            '${t1.baPublishedCount} B/A published',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: SoriTokens.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 24),
        const _SectionLabel('Revenue & reputation'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ChipMetric(
              label: 'Seminar hosted',
              value: '${t2.seminarHostedCount}',
            ),
            _ChipMetric(
              label: 'Seminar requests',
              value: '${t2.seminarRequestReceivedCount}',
            ),
            _ChipMetric(
              label: 'Follower',
              value: '${t2.followerCount}',
              onTap: () => showPeopleListSheet(
                context,
                store: widget.store,
                kind: PeopleListKind.follower,
              ),
            ),
            _ChipMetric(
              label: 'Supporter',
              value: '${t2.supporterCount}',
            ),
          ],
        ),
        if (t2.mentoringRevenueEchoTotal > 0) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SoriTokens.primarySoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: SoriTokens.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_open_rounded,
                    size: 20, color: SoriTokens.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Premium Mentoring · ${t2.mentoringRevenueEchoTotal}E',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        const _SectionLabel('Supporters'),
        const SizedBox(height: 10),
        if (supporters.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SoriTokens.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SoriTokens.border),
            ),
            child: const Text(
              'No Supporters yet.\nWhen someone boosts your cases, they appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          )
        else
          ...supporters.map((s) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: SoriTokens.background,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: s.customerId.isEmpty
                      ? null
                      : () => showSupporterInteractionStatementSheet(
                            context,
                            store: widget.store,
                            customerId: s.customerId,
                            displayName: s.displayName,
                            echoTotal: s.echoTotal,
                            avatarUrl: s.avatarUrl,
                          ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: SoriTokens.border),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: SoriTokens.primarySoft,
                          backgroundImage: (s.avatarUrl?.trim().isNotEmpty ??
                                  false)
                              ? NetworkImage(s.avatarUrl!.trim())
                              : null,
                          child: (s.avatarUrl?.trim().isEmpty ?? true)
                              ? Text(
                                  s.displayName.isNotEmpty
                                      ? s.displayName.characters.first
                                      : '?',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            s.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          '${s.echoTotal}E',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: SoriTokens.primary,
                          ),
                        ),
                        if (s.customerId.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: SoriTokens.textSecondary,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
        color: SoriTokens.textSecondary,
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: SoriTokens.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SoriTokens.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: SoriTokens.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: SoriTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipMetric extends StatelessWidget {
  const _ChipMetric({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoriTokens.background,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: SoriTokens.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SoriTokens.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
