import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/session_user.dart';
import 'package:sori/models/shop.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/biz_dashboard/biz_dashboard_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('경영 탭은 목표·매출·방문 없음을 0과 구분한다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SoriStore(repository: MemorySoriRepository());
    store.session = const SessionUser(
      role: UserRole.director,
      name: '테스트원장',
      phone: '010-0000-0000',
      provider: SocialProvider.kakao,
      authUserId: '00000000-0000-4000-8000-000000000001',
      onboardingComplete: true,
      shopSetupComplete: true,
      activeMode: UserRole.director,
    );
    store.shop = const Shop(
      id: 'shop-biz',
      name: '테스트샵',
      naverPlaceUrl: '',
    );

    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(400, 1600)),
        child: MaterialApp(
          home: Scaffold(
            body: DirectorBizTabBody(store: store, isOwner: true),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('경영'), findsOneWidget);
    expect(find.byKey(const Key('biz-target-gap')), findsOneWidget);
    expect(find.textContaining('아직 없음'), findsWidgets);
    expect(find.byKey(const Key('biz-extra-daily-visits')), findsOneWidget);
    expect(find.text('데이터 없음'), findsWidgets);
    expect(find.text('목표 없음'), findsWidgets);
    expect(find.byKey(const Key('biz-today-cta')), findsOneWidget);
    expect(find.text('목표 매출 계산하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
