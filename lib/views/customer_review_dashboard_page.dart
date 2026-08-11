import 'package:flutter/material.dart';

import '../models/customer_chart.dart';
import '../models/customer_review.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/sori_logo.dart';
import 'customer_review_history_page.dart';
import 'ikea_review_composer_page.dart';

/// 고객 모드 중앙 탭 — 리뷰 대시보드.
class CustomerReviewDashboardPage extends StatelessWidget {
  const CustomerReviewDashboardPage({super.key, required this.store});

  final SoriStore store;

  List<CustomerReview> _myReviews() {
    final customerId = store.session?.customerId;
    if (customerId == null) return const [];
    final list =
        store.reviews.where((r) => r.customerId == customerId).toList();
    list.sort((a, b) {
      final ad = a.acceptedAt ?? a.naverRegisteredAt ?? DateTime(2000);
      final bd = b.acceptedAt ?? b.naverRegisteredAt ?? DateTime(2000);
      return bd.compareTo(ad);
    });
    return list;
  }

  bool _hasChartHistory() {
    final customerId = store.session?.customerId;
    if (customerId == null) return false;
    return store.chartsForCustomer(customerId).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final shop = store.shop;
    final owner = (shop.ownerName ?? '').trim().isEmpty
        ? '원장'
        : shop.ownerName!.trim();
    final reviews = _myReviews();
    final hasShop = _hasChartHistory() || shop.name.trim().isNotEmpty;

    return ColoredBox(
      color: const Color(0xFFF5F6F8),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const Text(
              '리뷰 대시보드',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '방문한 샵과 나의 소통 리뷰를 한곳에서 관리해요',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 20),
            const _SectionTitle('내가 이용한 샵'),
            if (!hasShop)
              _EmptyCard(
                icon: Icons.storefront_outlined,
                message: '아직 이용한 샵이 없어요',
                subtitle: '원장님이 차트를 작성하면 여기에 표시돼요',
              )
            else
              _ShopUsedCard(
                shopName: shop.name,
                ownerName: owner,
                phone: shop.phone ?? '',
                visitHint: _hasChartHistory()
                    ? '차트 작성 이력이 있는 샵'
                    : '연동된 에스테틱 샵',
              ),
            const SizedBox(height: 22),
            const _SectionTitle('새 리뷰 작성하기'),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        backgroundColor: SoriTokens.background,
                        appBar: AppBar(
                          title: const Text('리뷰 작성'),
                          backgroundColor: Colors.white,
                          foregroundColor: SoriTokens.textPrimary,
                          elevation: 0,
                        ),
                        body: IkeaReviewComposerPage(store: store),
                      ),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome),
                label: const Text(
                  'SORI AI로 새 리뷰 작성하기',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(child: _SectionTitle('내가 작성한 후기')),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            CustomerReviewHistoryPage(store: store),
                      ),
                    );
                  },
                  child: const Text(
                    '전체 보기',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6C5CE7),
                    ),
                  ),
                ),
              ],
            ),
            if (reviews.isEmpty)
              const _EmptyCard(
                icon: Icons.rate_review_outlined,
                message: '작성한 후기가 아직 없어요',
                subtitle: 'AI로 리뷰를 작성하면 여기에 쌓여요',
              )
            else
              ...reviews.take(5).map((r) {
                CustomerChart? chart;
                for (final c in store.charts) {
                  if (c.id == r.chartId) {
                    chart = c;
                    break;
                  }
                }
                final title = chart?.careName.isNotEmpty == true
                    ? chart!.careName
                    : '소통 리뷰';
                final body = (r.editedText ?? r.originalText).trim();
                final when = r.acceptedAt ?? r.naverRegisteredAt;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReviewSnippetCard(
                    title: title,
                    body: body.isEmpty ? '작성된 본문이 없어요' : body,
                    dateLabel: when == null ? '' : _fmt(when),
                    naver: r.naverRegistered,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ShopUsedCard extends StatelessWidget {
  const _ShopUsedCard({
    required this.shopName,
    required this.ownerName,
    required this.phone,
    required this.visitHint,
  });

  final String shopName;
  final String ownerName;
  final String phone;
  final String visitHint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: SoriTokens.primarySoft,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: SoriLogo(width: 32, height: 32),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shopName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '원장 $ownerName${phone.isNotEmpty ? ' · $phone' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  visitHint,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6C5CE7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSnippetCard extends StatelessWidget {
  const _ReviewSnippetCard({
    required this.title,
    required this.body,
    required this.dateLabel,
    required this.naver,
  });

  final String title;
  final String body;
  final String dateLabel;
  final bool naver;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (naver)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8EF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '네이버',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.success,
                    ),
                  ),
                ),
            ],
          ),
          if (dateLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              dateLabel,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.message,
    required this.subtitle,
  });

  final IconData icon;
  final String message;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: Colors.grey[350]),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

String _fmt(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
