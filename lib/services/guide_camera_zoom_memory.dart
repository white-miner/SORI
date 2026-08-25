import 'package:shared_preferences/shared_preferences.dart';

/// 샵(기기)별 가이드 카메라 줌 배율 영속화.
class GuideCameraZoomMemory {
  GuideCameraZoomMemory._();

  static const double defaultZoom = 1.7;
  static const double minZoom = 1.0;
  static const double maxZoom = 2.6;

  static String _key(String shopId) {
    final sid = shopId.trim().isEmpty ? '_default' : shopId.trim();
    return 'guide_cam_zoom_v1_$sid';
  }

  static Future<double> load(String shopId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getDouble(_key(shopId));
      if (v == null) return defaultZoom;
      return v.clamp(minZoom, maxZoom);
    } catch (_) {
      return defaultZoom;
    }
  }

  static Future<void> save(String shopId, double zoom) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_key(shopId), zoom.clamp(minZoom, maxZoom));
    } catch (_) {}
  }
}
