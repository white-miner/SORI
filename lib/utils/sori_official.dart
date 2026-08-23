/// SORI Official brand persona — not Ops/admin.
abstract final class SoriOfficial {
  /// DB seed UUID (060).
  static const shopId = '00000000-0000-4000-8000-0000000000f1';

  /// Public handle / slug.
  static const slug = 'sori-official';

  static const displayName = 'SORI';

  static bool matchesShop({
    required String id,
    String slug = '',
    bool isOfficial = false,
  }) {
    if (isOfficial) return true;
    final sid = id.trim().toLowerCase();
    if (sid == shopId) return true;
    final s = slug.trim().toLowerCase();
    return s == SoriOfficial.slug;
  }
}
