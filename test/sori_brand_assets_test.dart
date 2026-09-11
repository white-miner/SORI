import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/theme/sori_brand_assets.dart';

void main() {
  test('logo uses single logo_sori.svg for all brightness', () {
    expect(
      SoriBrandAssets.logoForBrightness(Brightness.dark),
      SoriBrandAssets.logoSoriSvg,
    );
    expect(
      SoriBrandAssets.logoForBrightness(Brightness.light),
      SoriBrandAssets.logoSoriSvg,
    );
    expect(SoriBrandAssets.logoSoriSvg, 'assets/images/logo_sori.svg');
  });

  test('outline asset path matches logo_sori.svg', () {
    expect(SoriBrandAssets.outline, SoriBrandAssets.logoSoriSvg);
  });

  test('logo height tokens: GNB 34, hero 48–52 band', () {
    expect(SoriBrandAssets.logoHeightGnb, 34);
    expect(SoriBrandAssets.logoHeight, 48);
    expect(SoriBrandAssets.logoHeightHero, inInclusiveRange(44, 52));
  });
}
