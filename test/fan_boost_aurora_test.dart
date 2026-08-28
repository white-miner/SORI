import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/widgets/fan_boost_aurora_avatar.dart';

void main() {
  testWidgets('FanBoostAuroraAvatar builds for boosted and non-boosted',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FanBoostAuroraAvatar(
            key: Key('boosted'),
            imageUrl: '',
            isBoostActive: true,
            isFanBoost: true,
            radius: 18,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('boosted')), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FanBoostAuroraAvatar(
            key: Key('plain'),
            imageUrl: '',
            isBoostActive: false,
            isFanBoost: false,
            radius: 18,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('plain')), findsOneWidget);
  });
}
