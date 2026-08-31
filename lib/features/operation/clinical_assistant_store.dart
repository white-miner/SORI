import 'models/shop_climate_context.dart';

/// PRD v4.2 — 세션·브리핑용 현재 기후 SSOT (silent bind).
class ClinicalAssistantStore {
  ClinicalAssistantStore._();
  static final ClinicalAssistantStore instance = ClinicalAssistantStore._();

  ShopClimateContext? _current;

  ShopClimateContext? get current => _current;

  void setCurrent(ShopClimateContext ctx) => _current = ctx;

  void clear() => _current = null;
}
