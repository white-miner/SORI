import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/visit/profile_showcase.dart';
import '../features/visit/widgets/profile_featured_ba_picker_sheet.dart';
import '../models/customer_chart.dart';
import '../models/session_user.dart';
import '../services/profile_featured_ba_local.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/before_after_slider.dart';
import '../widgets/feed_ba_frame.dart';
import '../widgets/sori_action_buttons.dart';
import '../widgets/sori_logo.dart';

/// 원장 브랜드 프로필 — 소식 · 대표 전·후 · 스토리 · 예약|문의 CTA 1.
class DirectorFandomProfilePage extends StatefulWidget {
  const DirectorFandomProfilePage({
    super.key,
    required this.store,
    this.isOwner,
  });

  final SoriStore store;

  /// null이면 director 세션일 때만 관리 CTA (외부 공개 URL은 명시 false).
  final bool? isOwner;

  @override
  State<DirectorFandomProfilePage> createState() =>
      _DirectorFandomProfilePageState();
}

class _DirectorFandomProfilePageState extends State<DirectorFandomProfilePage> {
  SoriStore get store => widget.store;
  List<String> _featuredIds = const [];
  bool _loadingFeatured = true;

  bool get _isOwner {
    if (widget.isOwner != null) return widget.isOwner!;
    return store.session?.activeMode == UserRole.director;
  }

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    _loadFeatured();
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Future<void> _loadFeatured() async {
    final ids = await ProfileFeaturedBaLocal.load(store.shop.id);
    if (!mounted) return;
    setState(() {
      _featuredIds = ids;
      _loadingFeatured = false;
    });
  }

  List<CustomerChart> get _displayCases =>
      ProfileShowcase.displayFeaturedCases(
        featuredIds: _featuredIds,
        charts: store.charts,
      );

  String get _title {
    final shopName =
        store.shop.name.trim().isEmpty ? 'SORI' : store.shop.name.trim();
    final owner = (store.shop.ownerName ?? '').trim();
    if (owner.isEmpty) return '$shopName 원장';
    return owner.contains('원장') ? '$shopName $owner' : '$shopName $owner 원장';
  }

  ProfilePublicCta get _cta => ProfileShowcase.resolveCta(
        bookingOrPlaceUrl: store.shop.naverBookingOrPlaceUrl,
        phone: store.shop.phone,
      );

  Future<void> _onCta() async {
    final cta = _cta;
    if (!cta.showsButton || cta.launchUri == null) return;
    try {
      final ok = await launchUrl(
        cta.launchUri!,
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        _ctaFailedFallback(cta);
      }
    } catch (_) {
      if (mounted) _ctaFailedFallback(cta);
    }
  }

  void _ctaFailedFallback(ProfilePublicCta attempted) {
    if (attempted.kind == ProfilePublicCtaKind.book) {
      final phoneCta = ProfileShowcase.resolveCta(
        bookingOrPlaceUrl: '',
        phone: store.shop.phone,
      );
      if (phoneCta.showsButton) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('예약 페이지를 열 수 없어요. 문의하기를 이용해 주세요.'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: '문의하기',
              onPressed: () async {
                final uri = phoneCta.launchUri;
                if (uri == null) return;
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
          ),
        );
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('연결에 실패했어요. 잠시 후 다시 시도해 주세요.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openFeaturedPicker() async {
    if (!_isOwner) return;
    final next = await showProfileFeaturedBaPickerSheet(
      context: context,
      charts: store.charts,
      initialFeaturedIds: _featuredIds,
    );
    if (next == null || !mounted) return;
    await ProfileFeaturedBaLocal.save(store.shop.id, next);
    if (!mounted) return;
    setState(() => _featuredIds = next);
  }

  @override
  Widget build(BuildContext context) {
    final following = store.isFollowingShop();
    final tip = store.todayHomecareTip.trim().isEmpty
        ? '오늘도 건강한 피부를 선물해 드릴게요'
        : store.todayHomecareTip.trim();
    final slides = store.gallerySlides;
    final cases = _displayCases;
    final cta = _cta;
    final showShowcaseSection =
        _isOwner || cases.isNotEmpty || (_isOwner && _loadingFeatured);

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: const Text(
          '원장 프로필',
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
                // Level 1 = 예약|문의만 filled brand. 팔로우는 secondary.
                if (cta.showsButton)
                  Semantics(
                    button: true,
                    label: cta.label,
                    hint: cta.semanticsHint,
                    child: SoriPrimaryButton(
                      label: cta.label,
                      onPressed: _onCta,
                    ),
                  )
                else if (cta.helperText != null)
                  Text(
                    cta.helperText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: SoriTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 10),
                SoriSecondaryButton(
                  label: following ? '팔로잉' : '팔로우',
                  onPressed: () {
                    final on = store.toggleFollowShop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          on ? '팔로워로 등록했어요' : '팔로우를 해제했어요',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
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
          if (showShowcaseSection) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    cases.isEmpty
                        ? '대표 사례'
                        : '대표 사례 · ${cases.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_isOwner)
                  TextButton(
                    key: const Key('profile_featured_ba_manage'),
                    onPressed: _openFeaturedPicker,
                    style: TextButton.styleFrom(
                      foregroundColor: SoriTokens.brand,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      '대표 사례 관리',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loadingFeatured)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (cases.isEmpty)
              Text(
                _isOwner
                    ? (store.charts.any(ProfileShowcase.isShowcaseEligible)
                        ? '대표 사례를 선택해 보세요'
                        : '커뮤니티 공개·동의된 사례가 생기면 선택할 수 있어요')
                    : '등록된 대표 사례가 아직 없어요',
                style: const TextStyle(color: SoriTokens.textSecondary),
              )
            else
              ...cases.map(_buildCaseCard),
          ],
        ],
      ),
    );
  }

  Widget _buildCaseCard(CustomerChart chart) {
    final care =
        chart.careName.trim().isEmpty ? '관리 케어' : chart.careName.trim();
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
                  fallbackLabel: '전',
                  tone: SoriTokens.brand,
                ),
                after: ChartImagePane(
                  url: chart.afterImageUrl,
                  fallbackLabel: '후',
                  tone: SoriTokens.brand,
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
  }
}
