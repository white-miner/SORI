import 'models/shop_climate_context.dart';
import 'models/clinical_trend_snapshot.dart';

/// PRD v4.2 + v4.3 — 세션·브리핑용 climate + trend SSOT.
class ClinicalAssistantStore {
  ClinicalAssistantStore._();
  static final ClinicalAssistantStore instance = ClinicalAssistantStore._();

  ShopClimateContext? _current;
  ClinicalTrendSnapshot? _trends;

  ShopClimateContext? get current => _current;
  ClinicalTrendSnapshot? get trends => _trends;

  void setCurrent(ShopClimateContext ctx) => _current = ctx;

  void setTrends(ClinicalTrendSnapshot snapshot) => _trends = snapshot;

  void clear() {
    _current = null;
    _trends = null;
  }
}
