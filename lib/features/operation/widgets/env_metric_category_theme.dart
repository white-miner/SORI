import 'package:flutter/material.dart';

/// PO ENV override — category identity colors (arc), not semantic status.
enum EnvMetricCategory {
  temperature,
  uv,
  humidity,
  pm25,
}

abstract final class EnvMetricCategoryTheme {
  /// Yellow → orange (temperature).
  static const tempGradient = [
    Color(0xFFFFCC00),
    Color(0xFFFF9500),
  ];

  /// iOS vibrant orange (UV).
  static const uv = Color(0xFFFF9500);

  /// iOS system blue (humidity — always blue).
  static const humidity = Color(0xFF32ADE6);

  /// iOS system purple (PM2.5).
  static const pm25 = Color(0xFFBF5AF2);

  static Color arcColor(EnvMetricCategory category) => switch (category) {
        EnvMetricCategory.temperature => tempGradient.last,
        EnvMetricCategory.uv => uv,
        EnvMetricCategory.humidity => humidity,
        EnvMetricCategory.pm25 => pm25,
      };

  static List<Color>? arcGradient(EnvMetricCategory category) =>
      category == EnvMetricCategory.temperature ? tempGradient : null;
}
