import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/theme/sori_brand_assets.dart';
import 'package:sori/widgets/sori_logo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SoriLogo default render uses GNB height', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: const Scaffold(
          body: Center(child: SoriLogo()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    final box = tester.renderObject<RenderBox>(find.byType(SoriLogo));
    expect(box.size.height, SoriLogo.gnbHeight);
    expect(box.size.height, SoriBrandAssets.logoHeightGnb);
  });

  testWidgets('SoriLogo height parameter uses logoHeight token', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SoriLogo(height: SoriBrandAssets.logoHeight),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    final box = tester.renderObject<RenderBox>(find.byType(SoriLogo));
    expect(box.size.height, SoriBrandAssets.logoHeight);
  });
}
