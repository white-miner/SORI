import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/visit/home_visual_tokens.dart';
import 'package:sori/utils/sori_bottom_sheet.dart';

void main() {
  test('Phase A week day cell min hit is at least 48', () {
    expect(HomeVisualTokens.weekDayCellMinHeight, greaterThanOrEqualTo(48));
  });

  test('floating nav clearance is applied as content padding budget', () {
    expect(kSoriFloatingNavClearance, greaterThanOrEqualTo(80));
  });
}
