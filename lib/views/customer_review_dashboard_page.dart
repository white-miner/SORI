import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer_chart.dart';
import '../models/customer_review.dart';
import '../models/shop.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/sori_logo.dart';
import 'customer_review_history_page.dart';
import 'ikea_review_composer_page.dart';

/// 고객 모드 중앙 탭 — 동적 리뷰 대시보드.
class CustomerReviewDashboardPage extends StatefulWidget {
  const CustomerReviewDashboardPage({super.key, required this.store});

  final SoriStore store;

  @override
  State<CustomerReviewDashboardPage> createState() =>
      _CustomerReviewDashboardPageState();
}

class _CustomerReviewDashboardPageState
    extends State<CustomerReviewDashboardPage> {
  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

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

  /// 차트는 있으나 리뷰가 없는 방문 = 작성 대기.
  List<CustomerChart> _pendingCharts() {
    final customerId = store.session?.customerId;
    if (customerId == null) return const [];
    final list = store.chartsForCustomer(customerId).where((c) {
      return store.reviewForChart(c.id) == null;
    }).toList();
    list.sort((a, b) {
      final ad = a.visitCheckedAt ?? a.createdAt ?? DateTime(2000);
      final bd = b.visitCheckedAt ?? b.createdAt ?? DateTime(2000);
      return bd.compareTo(ad);
    });
    return list;
  }

  bool _hasChartHistory() {
    final customerId = store.session?.customerId;
    if (customerId == null) return false;
    return store.chartsForCustomer(customerId).isNotEmpty;
  }

  Future<void> _openNaverPlace(Shop shop, {bool reviewDeepLink = false}) async {
    final url = reviewDeepLink
        ? shop.naverReviewDeepLink.trim()
        : shop.naverPlaceUrl.trim();
    if (url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('네이버 예약 링크가 준비 중입니다.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: SoriTokens.primaryDark,
        ),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('네이버 예약 링크가 준비 중입니다.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: SoriTokens.primaryDark,
        ),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showShopMiniProfile(Shop shop) {
    final owner = (shop.ownerName ?? '').trim().isEmpty
        ? '원장'
        : shop.ownerName!.trim();
    final hours = shop.operatingHours.trim().isEmpty
        ? '영업시간 미등록'
        : shop.operatingHours.trim();
    final address =
        (shop.address ?? '').trim().isEmpty ? '주소 미등록' : shop.address!.trim();
    final phone = (shop.phone ?? '').trim();

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: SoriTokens.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.paddingOf(ctx).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: SoriTokens.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 18),
              CircleAvatar(
                radius: 36,
                backgroundColor: SoriTokens.primarySoft,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: SoriLogo(width: 48, height: 48),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                shop.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '원장 $owner',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: SoriTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _InfoRow(icon: Icons.schedule_rounded, text: hours),
              const SizedBox(height: 8),
              _InfoRow(icon: Icons.place_outlined, text: address),
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 8),
                _InfoRow(icon: Icons.phone_outlined, text: phone),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openNaverPlace(shop);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: SoriTokens.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '네이버 플레이스 예약',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openAiReview(CustomerChart chart) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: SoriTokens.background,
          appBar: AppBar(
            title: Text(
              chart.careName.isNotEmpty ? '${chart.careName} 리뷰' : 'AI 리뷰 작성',
            ),
            backgroundColor: SoriTokens.surface,
            foregroundColor: SoriTokens.textPrimary,
            elevation: 0,
          ),
          body: IkeaReviewComposerPage(store: store, chart: chart),
        ),
      ),
    );
  }

  Future<void> _shareToNaver(CustomerReview review) async {
    final text = (review.editedText ?? review.originalText).trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('복사할 리뷰 본문이 없어요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('리뷰가 복사되었습니다. 네이버 플레이스로 이동합니다.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: SoriTokens.primary,
      ),
    );
    await store.markNaverRegistered(chartId: review.chartId, composedText: text);
    if (!mounted) return;
    await _openNaverPlace(store.shop, reviewDeepLink: true);
  }

  @override
  Widget build(BuildContext context) {
    final shop = store.shop;
    final owner = (shop.ownerName ?? '').trim().isEmpty
        ? '원장'
        : shop.ownerName!.trim();
    final reviews = _myReviews();
    final pending = _pendingCharts();
    final hasShop = _hasChartHistory() || shop.name.trim().isNotEmpty;

    return ColoredBox(
      color: SoriTokens.background,
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
                color: SoriTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '방문 케어에 맞춰 리뷰를 작성하고 네이버에 공유해요',
              style: TextStyle(
                fontSize: 13,
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 20),
            const _SectionTitle('내가 이용한 샵'),
            if (!hasShop)
              const _EmptyCard(
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
                    ? '차트 작성 이력이 있는 샵 · 터치하여 프로필'
                    : '연동된 에스테틱 샵 · 터치하여 프로필',
                onTap: () => _showShopMiniProfile(shop),
              ),
            const SizedBox(height: 22),
            const _SectionTitle('작성 대기 중인 케어 내역'),
            if (pending.isEmpty)
              const _EmptyCard(
                icon: Icons.spa_outlined,
                message: '작성 대기 중인 케어가 없어요',
                subtitle: '방문 후 차트가 열리면 여기에 표시돼요',
              )
            else
              ...pending.map(
                (chart) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PendingCareCard(
                    shopName: shop.name,
                    careName: chart.careName.isNotEmpty
                        ? chart.careName
                        : (chart.treatmentSummary.isNotEmpty
                            ? chart.treatmentSummary
                            : '케어'),
                    visitLabel: chart.visitNumber > 0
                        ? '${chart.visitNumber}회차'
                        : '',
                    dateLabel: _fmt(
                      chart.visitCheckedAt ?? chart.createdAt,
                    ),
                    onWrite: () => _openAiReview(chart),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(child: _SectionTitle('내가 작성한 후기')),
                TextButton(
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).push(
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
                      color: SoriTokens.primary,
                    ),
                  ),
                ),
              ],
            ),
            if (reviews.isEmpty)
              const _EmptyCard(
                icon: Icons.rate_review_outlined,
                message: '작성한 후기가 아직 없어요',
                subtitle: '대기 중인 케어에서 AI 리뷰를 작성해 보세요',
              )
            else
              ...reviews.take(8).map((r) {
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
                    naverDone: r.naverRegistered,
                    onNaver: () => _shareToNaver(r),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: SoriTokens.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: SoriTokens.textSecondary,
            ),
          ),
        ),
      ],
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
          color: SoriTokens.textPrimary,
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
    required this.onTap,
  });

  final String shopName;
  final String ownerName;
  final String phone;
  final String visitHint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SoriTokens.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
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
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      visitHint,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: SoriTokens.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_up_rounded, color: SoriTokens.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingCareCard extends StatelessWidget {
  const _PendingCareCard({
    required this.shopName,
    required this.careName,
    required this.visitLabel,
    required this.dateLabel,
    required this.onWrite,
  });

  final String shopName;
  final String careName;
  final String visitLabel;
  final String dateLabel;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SoriTokens.border),
        boxShadow: SoriTokens.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  careName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: SoriTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    shopName,
                    if (visitLabel.isNotEmpty) visitLabel,
                    if (dateLabel.isNotEmpty) dateLabel,
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    color: SoriTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onWrite,
            style: FilledButton.styleFrom(
              backgroundColor: SoriTokens.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'AI 리뷰 쓰기',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
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
    required this.naverDone,
    required this.onNaver,
  });

  final String title;
  final String body;
  final String dateLabel;
  final bool naverDone;
  final VoidCallback onNaver;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SoriTokens.border),
        boxShadow: SoriTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: SoriTokens.textPrimary,
                  ),
                ),
              ),
              if (naverDone)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: SoriTokens.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '네이버 등록',
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
              style: const TextStyle(fontSize: 11, color: SoriTokens.textSecondary),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onNaver,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(
                naverDone ? '네이버 리뷰 다시 남기기' : '네이버 리뷰 남기기',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: SoriTokens.success,
                side: const BorderSide(color: SoriTokens.success),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
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
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SoriTokens.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: SoriTokens.textSecondary),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: SoriTokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

String _fmt(DateTime? d) {
  if (d == null) return '';
  return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}
