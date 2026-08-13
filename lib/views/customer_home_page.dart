import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/sori_card.dart';

/// 고객 홈 — 대시보드 (웰컴 · 리뷰 요청 · 샵 퀵액션).
class CustomerHomePage extends StatelessWidget {
  const CustomerHomePage({
    super.key,
    required this.store,
    this.onSelectTab,
  });

  final SoriStore store;
  final ValueChanged<int>? onSelectTab;

  @override
  Widget build(BuildContext context) {
    final session = store.session!;
    final customerId = session.customerId;
    final name = session.name.trim().isEmpty ? '고객' : session.name.trim();
    final hasReviewRequest =
        customerId != null && store.isReviewRequested(customerId);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          if (hasReviewRequest) ...[
            _ReviewRequestBanner(onTap: () => onSelectTab?.call(2)),
            const SizedBox(height: 12),
          ],
          SoriCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: SoriTokens.primarySoft,
                  child: Text(
                    name.characters.first,
                    style: const TextStyle(
                      color: SoriTokens.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$name님, 환영합니다',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '오늘도 편안한 케어 되세요',
                        style: TextStyle(
                          fontSize: 13,
                          color: SoriTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '내 에스테틱 샵',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _ShopSummaryCard(store: store),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _QuickNavChip(
                  icon: Icons.spa_outlined,
                  label: '내 케어',
                  onTap: () => onSelectTab?.call(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickNavChip(
                  icon: Icons.chat_bubble_outline,
                  label: '리뷰 작성',
                  onTap: () => onSelectTab?.call(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewRequestBanner extends StatelessWidget {
  const _ReviewRequestBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SoriTokens.radiusXl),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5B4CDB), Color(0xFF7C6FF0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(SoriTokens.radiusXl),
            boxShadow: [
              BoxShadow(
                color: SoriTokens.primary.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            children: [
              Text('📝', style: TextStyle(fontSize: 28)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '오늘 케어의 리뷰를 조립해 주세요!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopSummaryCard extends StatelessWidget {
  const _ShopSummaryCard({required this.store});

  final SoriStore store;

  Future<void> _call() async {
    final phone = store.shop.phone?.replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone == null || phone.isEmpty) return;
    await launchUrl(Uri.parse('tel:$phone'));
  }

  Future<void> _openPlace() async {
    final uri = Uri.tryParse(store.shop.naverPlaceUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = store.shop;
    final owner = (shop.ownerName == null || shop.ownerName!.trim().isEmpty)
        ? '원장'
        : shop.ownerName!.trim();

    return SoriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: SoriTokens.primarySoft,
                child: Text(
                  owner.characters.first,
                  style: const TextStyle(
                    color: SoriTokens.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shop.address?.isNotEmpty == true
                          ? shop.address!
                          : '$owner 원장님',
                      style: const TextStyle(
                        fontSize: 12,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.phone_outlined,
                  label: '전화 걸기',
                  onTap: _call,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.place_outlined,
                  label: '샵 위치',
                  onTap: _openPlace,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: SoriTokens.primary,
        side: const BorderSide(color: SoriTokens.border),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _QuickNavChip extends StatelessWidget {
  const _QuickNavChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoriCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: SoriTokens.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
