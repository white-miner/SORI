import 'package:shared_preferences/shared_preferences.dart';

/// 경영 대시보드 — 월/년 매출 수동 입력 (Phase 0.5).
/// 기기 로컬. 추후 Supabase Expand · 차트 결제 연동은 별 PR.
abstract final class BizManualRevenueStore {
  static String _monthKey(String shopId, int year, int month) =>
      'biz_rev_month_${shopId.trim()}_${year}_${month.toString().padLeft(2, '0')}';

  static String _yearKey(String shopId, int year) =>
      'biz_rev_year_${shopId.trim()}_$year';

  static Future<int?> loadMonth({
    required String shopId,
    required int year,
    required int month,
  }) async {
    if (shopId.trim().isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_monthKey(shopId, year, month))) return null;
    return prefs.getInt(_monthKey(shopId, year, month));
  }

  static Future<void> saveMonth({
    required String shopId,
    required int year,
    required int month,
    required int amountKrw,
  }) async {
    if (shopId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_monthKey(shopId, year, month), amountKrw);
  }

  static Future<int?> loadYear({
    required String shopId,
    required int year,
  }) async {
    if (shopId.trim().isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_yearKey(shopId, year))) return null;
    return prefs.getInt(_yearKey(shopId, year));
  }

  static Future<void> saveYear({
    required String shopId,
    required int year,
    required int amountKrw,
  }) async {
    if (shopId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_yearKey(shopId, year), amountKrw);
  }

  static String formatWon(int amount) {
    final digits = amount.toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final fromEnd = digits.length - i;
      buf.write(digits[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return '$buf원';
  }
}
