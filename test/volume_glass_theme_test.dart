import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/operation/widgets/volume_glass_theme.dart';
import 'package:sori/theme/sori_tokens.dart';

void main() {
  group('PRD v4.7 VolumeGlassTheme', () {
    test('canvas and card tokens match PO §9', () {
      expect(VolumeGlassTheme.canvasBg, const Color(0xFFF4F6F9));
      expect(SoriTokens.background, VolumeGlassTheme.canvasBg);
      expect(VolumeGlassTheme.cardRadius, 24.0);
      expect(VolumeGlassTheme.cardPadding, const EdgeInsets.all(20));
    });

    test('volume shadow uses soft blur and low alpha', () {
      final shadows = VolumeGlassTheme.volumeShadow();
      expect(shadows, hasLength(1));
      expect(shadows.first.blurRadius, inInclusiveRange(20, 30));
      expect(shadows.first.offset, const Offset(0, 8));
      expect(shadows.first.color.a, inInclusiveRange(0.04, 0.08));
    });

    test('KPI typography is bold and large', () {
      final kpi = VolumeGlassTheme.kpiTextStyle();
      expect(kpi.fontSize, greaterThanOrEqualTo(32));
      expect(kpi.fontWeight, FontWeight.w800);
    });

    test('label typography is smaller grey', () {
      final label = VolumeGlassTheme.labelTextStyle();
      expect(label.fontSize, inInclusiveRange(12, 14));
      expect(label.fontWeight, FontWeight.w600);
    });

    test('care primary uses vibrant green', () {
      expect(VolumeGlassTheme.vibrantCareGreen, const Color(0xFF34C759));
    });
  });
}
