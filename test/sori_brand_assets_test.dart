import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/theme/sori_brand_assets.dart';

void main() {
  test('logo switches by brightness', () {
    expect(
      SoriBrandAssets.logoForBrightness(Brightness.dark),
      SoriBrandAssets.logoWhite,
    );
    expect(
      SoriBrandAssets.logoForBrightness(Brightness.light),
      SoriBrandAssets.logoBlack,
    );
  });

  test('outline asset path is stable', () {
    expect(SoriBrandAssets.outline, 'assets/images/logo_outline.png');
  });
}
