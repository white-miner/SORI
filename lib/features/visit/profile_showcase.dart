import '../../models/customer_chart.dart';

/// PRD v7.9 Phase 5 — 공개 프로필 대표 B/A · 예약|문의 CTA (순수).
enum ProfilePublicCtaKind { book, inquire, none }

class ProfilePublicCta {
  const ProfilePublicCta({
    required this.kind,
    required this.label,
    this.launchUri,
    this.helperText,
    this.semanticsHint,
  });

  final ProfilePublicCtaKind kind;
  final String label;
  final Uri? launchUri;
  final String? helperText;
  final String? semanticsHint;

  bool get showsButton => kind != ProfilePublicCtaKind.none;
}

abstract final class ProfileShowcase {
  ProfileShowcase._();

  static const int maxFeatured = 5;
  static const String preparingHint = '예약 방법을 준비 중이에요';

  static bool hasShowcaseImage(CustomerChart chart) {
    final b = chart.beforeImageUrl?.trim() ?? '';
    final a = chart.afterImageUrl?.trim() ?? '';
    return b.isNotEmpty || a.isNotEmpty;
  }

  /// 쇼케이스 노출·선택 후보 공통 조건.
  static bool isShowcaseEligible(CustomerChart chart) {
    if (!chart.caseShared) return false;
    if (!chart.isConsentSigned) return false;
    return hasShowcaseImage(chart);
  }

  /// prefs 순서 보존 · 매 호출 재검증 · 자동 unset 없음.
  static List<CustomerChart> displayFeaturedCases({
    required List<String> featuredIds,
    required Iterable<CustomerChart> charts,
  }) {
    final byId = <String, CustomerChart>{
      for (final c in charts)
        if (c.id.trim().isNotEmpty) c.id.trim(): c,
    };
    final out = <CustomerChart>[];
    for (final raw in featuredIds) {
      final id = raw.trim();
      if (id.isEmpty) continue;
      final chart = byId[id];
      if (chart == null) continue;
      if (!isShowcaseEligible(chart)) continue;
      out.add(chart);
      if (out.length >= maxFeatured) break;
    }
    return out;
  }

  /// 선택 순 = 표시 순. 이미 있으면 유지. 5개면 null(거절).
  static List<String>? tryAddFeatured(List<String> current, String chartId) {
    final id = chartId.trim();
    if (id.isEmpty) return null;
    final next = normalizeFeaturedIds(current);
    if (next.contains(id)) return List<String>.from(next);
    if (next.length >= maxFeatured) return null;
    return [...next, id];
  }

  static List<String> removeFeatured(List<String> current, String chartId) {
    final id = chartId.trim();
    return normalizeFeaturedIds(current).where((e) => e != id).toList();
  }

  /// 피커 저장: 전달 순서 유지 · max 5 · 중복 제거.
  static List<String> normalizeFeaturedIds(Iterable<String> ids) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in ids) {
      final id = raw.trim();
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      out.add(id);
      if (out.length >= maxFeatured) break;
    }
    return out;
  }

  static bool isHttpUrl(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return false;
    final u = Uri.tryParse(t);
    if (u == null) return false;
    if (u.scheme != 'http' && u.scheme != 'https') return false;
    return u.host.isNotEmpty;
  }

  static String digitsOnly(String phone) =>
      phone.replaceAll(RegExp(r'[^0-9]'), '');

  static bool hasPublicPhone(String? phone) => digitsOnly(phone ?? '').length >= 10;

  /// booking/place SSOT → 예약하기 · 없으면 전화 문의 · 둘 다 없으면 숨김.
  static ProfilePublicCta resolveCta({
    required String bookingOrPlaceUrl,
    String? phone,
  }) {
    if (isHttpUrl(bookingOrPlaceUrl)) {
      return ProfilePublicCta(
        kind: ProfilePublicCtaKind.book,
        label: '예약하기',
        launchUri: Uri.parse(bookingOrPlaceUrl.trim()),
        semanticsHint: '네이버 등 외부 예약 페이지로 이동합니다',
      );
    }
    final digits = digitsOnly(phone ?? '');
    if (digits.length >= 10) {
      return ProfilePublicCta(
        kind: ProfilePublicCtaKind.inquire,
        label: '문의하기',
        launchUri: Uri.parse('tel:$digits'),
      );
    }
    return const ProfilePublicCta(
      kind: ProfilePublicCtaKind.none,
      label: '',
      helperText: preparingHint,
    );
  }
}
