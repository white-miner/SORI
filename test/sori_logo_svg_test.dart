import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/theme/sori_brand_assets.dart';
import 'package:sori/widgets/sori_logo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SvgPicture loads white logo asset', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SvgPicture.asset(
            SoriBrandAssets.logoWhite,
            height: 48,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('SoriLogo renders at fixed height', (tester) async {
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
    expect(box.size.height, SoriBrandAssets.logoHeight);
  });
}
