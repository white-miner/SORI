import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/models/session_user.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/app_settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('AppSettings R4 sections hide mode toggle', (tester) async {
    final store = SoriStore();
    store.session = const SessionUser(
      role: UserRole.director,
      name: '테스트원장',
      phone: '01000000000',
      provider: SocialProvider.kakao,
      onboardingComplete: true,
      shopSetupComplete: true,
      activeMode: UserRole.director,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppSettingsPage(store: store),
      ),
    );
    await tester.pump();

    expect(find.text('계정'), findsOneWidget);
    expect(find.text('내 샵과 공개'), findsOneWidget);
    expect(find.text('알림'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('원장 모드'), findsNothing);
  });
}
