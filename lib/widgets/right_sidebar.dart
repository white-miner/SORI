import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/shop_tier_badge_chip.dart';

/// PC 와이드 뷰포트(>=1200px)에서 피드 우측에 고정되는 대시보드 사이드바.
class RightSidebar extends StatelessWidget {
  const RightSidebar({super.key});

  static const double width = 320;

  @override
  Widget build(BuildContext context) {
    final store = SoriStore.instance;
    final session = store.session;
    if (session == null) return const SizedBox.shrink();

    final shop = store.shop;
    final month = DateTime.now().month;
    final reqCount = store.seminarEducationInsight?.totalRequests ?? 0;

    return SizedBox(
      width: width,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        children: [
          _TierCard(shop: shop),
          const SizedBox(height: 12),
          _AiSummaryCard(month: month),
          const SizedBox(height: 12),
          _SeminarCard(count: reqCount),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.shop});
  final Shop shop;

  @override
  Widget build(BuildContext context) {
    final snap = shop.tierProgress;
    final pct = ((snap.socialRatio > snap.businessRatio
                ? snap.socialRatio
                : snap.businessRatio) *
            100)
        .round()
        .clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E4F8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.military_tech_rounded,
                  size: 20, color: Color(0xFFB7791F)),
              const SizedBox(width: 6),
              const Text('내 등급',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800)),
              const Spacer(),
              ShopTierBadgeChip(badge: shop.tierBadge, compact: true),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 6,
              backgroundColor: const Color(0xFFEDE9FE),
              color: SoriTokens.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '달성률 $pct%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiSummaryCard extends StatelessWidget {
  const _AiSummaryCard({required this.month});
  final int month;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph_rounded,
                  size: 20, color: Color(0xFF0F766E)),
              const SizedBox(width: 6),
              Text('AI 경영 · $month월',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '이번 달 AI 리포트를 확인하세요',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeminarCard extends StatelessWidget {
  const _SeminarCard({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school_rounded,
                  size: 20, color: SoriTokens.primary),
              const SizedBox(width: 6),
              const Text('추천 세미나',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '세미나 요청 $count건',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
