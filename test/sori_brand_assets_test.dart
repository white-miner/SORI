import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/theme/sori_brand_assets.dart';

void main() {
  test('logo switches by brightness to SVG paths', () {
    expect(
      SoriBrandAssets.logoForBrightness(Brightness.dark),
      'assets/images/logo_white.svg',
    );
    expect(
      SoriBrandAssets.logoForBrightness(Brightness.light),
      'assets/images/logo_black.svg',
    );
  });

  test('outline asset path is SVG', () {
    expect(SoriBrandAssets.outline, 'assets/images/logo_outline.svg');
  });

  test('logo height tokens are in 44–52 band', () {
    expect(SoriBrandAssets.logoHeight, inInclusiveRange(44, 52));
    expect(SoriBrandAssets.logoHeightHero, inInclusiveRange(44, 52));
  });
}
