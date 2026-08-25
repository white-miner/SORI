import 'package:flutter/material.dart';

import '../models/customer_chart.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/before_after_slider.dart';
import '../widgets/feed_ba_frame.dart';
import '../widgets/sori_logo.dart';

/// 원장 브랜드 팬덤 프로필 — 소식 · B/A 케이스 · 스토리.
class DirectorFandomProfilePage extends StatefulWidget {
  const DirectorFandomProfilePage({super.key, required this.store});

  final SoriStore store;

  @override
  State<DirectorFandomProfilePage> createState() =>
      _DirectorFandomProfilePageState();
}

class _DirectorFandomProfilePageState extends State<DirectorFandomProfilePage> {
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

  List<CustomerChart> get _cases {
    final out = <CustomerChart>[];
    for (final chart in store.charts) {
      if (!chart.caseShared || !chart.isConsentSigned) continue;
      final b = chart.beforeImageUrl?.trim() ?? '';
      final a = chart.afterImageUrl?.trim() ?? '';
      if (b.isEmpty && a.isEmpty) continue;
      out.add(chart);
    }
    return out;
  }

  String get _title {
    final shopName =
        store.shop.name.trim().isEmpty ? 'SORI' : store.shop.name.trim();
    final owner = (store.shop.ownerName ?? '').trim();
    if (owner.isEmpty) return '$shopName 원장';
    return owner.contains('원장') ? '$shopName $owner' : '$shopName $owner 원장';
  }

  @override
  Widget build(BuildContext context) {
    final following = store.isFollowingShop();
    final tip = store.todayHomecareTip.trim().isEmpty
        ? '오늘도 건강한 피부를 선물해 드릴게요'
        : store.todayHomecareTip.trim();
    final slides = store.gallerySlides;
    final cases = _cases;

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: const Text(
          '원장 팬덤 프로필',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: SoriTokens.surface,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: SoriTokens.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: SoriTokens.primary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [SoriTokens.primary, SoriTokens.primaryLight],
                    ),
                    border: Border.all(color: SoriTokens.surface, width: 3),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(18),
                    child: SoriLogo(width: 52, height: 52),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tip,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: SoriTokens.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final on = store.toggleFollowShop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            on ? '단골 팬으로 등록했어요' : '단골 팬 등록을 해제했어요',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: Icon(
                      following
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                    ),
                    label: Text(
                      following ? '단골 팬 · 팔로잉' : '단골 팬 등록 / 팔로우',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: SoriTokens.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            '소식',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SoriTokens.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '오늘의 홈케어 팁\n$tip',
              style: const TextStyle(height: 1.45, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            '스토리',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (slides.isEmpty)
            const Text(
              '등록된 스토리가 아직 없어요',
              style: TextStyle(color: SoriTokens.textSecondary),
            )
          else
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: slides.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final s = slides[i];
                  return Container(
                    width: 108,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A1A1A), Color(0xFF222222)],
                      ),
                      border: Border.all(
                        color: SoriTokens.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          s.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: SoriTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 22),
          Text(
            'B/A 케이스 모음 · ${cases.length}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (cases.isEmpty)
            const Text(
              '공유된 케이스가 없습니다',
              style: TextStyle(color: SoriTokens.textSecondary),
            )
          else
            ...cases.take(8).map((chart) {
              final care =
                  chart.careName.trim().isEmpty ? '관리 케어' : chart.careName;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: SoriTokens.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FeedBaFrame(
                        child: BeforeAfterSlider(
                          aspectRatio: 1.0,
                          maxHeight: FeedBaFrame.maxSide,
                          borderRadius: BorderRadius.zero,
                          before: ChartImagePane(
                            url: chart.beforeImageUrl,
                            fallbackLabel: 'Before',
                            tone: SoriTokens.primary,
                          ),
                          after: ChartImagePane(
                            url: chart.afterImageUrl,
                            fallbackLabel: 'After',
                            tone: const Color(0xFF03C75A),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          care,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
