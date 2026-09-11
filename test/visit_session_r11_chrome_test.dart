import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/visit/consultation_track.dart';
import 'package:sori/features/visit/visit_session_page.dart';
import 'package:sori/services/sori_store.dart';

/// R1-1 chrome: 요약 히어로가 phase와 무관하게 보인다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('VisitSession shows 오늘의 케어 요약 hero above phases', (
    tester,
  ) async {
    final store = SoriStore();
    final customer = store.customers.first;
    final session = await store.startVisitSession(customerId: customer.id);

    await tester.pumpWidget(
      MaterialApp(
        home: VisitSessionPage(
          store: store,
          sessionId: session.id,
          track: ConsultationTrack.returning,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('오늘의 케어 요약'), findsOneWidget);
    expect(find.text('오늘 어떤 케어를 진행했나요?'), findsOneWidget);
    expect(
      find.textContaining('사진은 필요할 때 추가할 수 있어요'),
      findsWidgets,
    );
    // 파이프라인 레일·본문에 동일 라벨이 중복될 수 있음 — 삭제되지 않았는지만 확인
    expect(find.text('촬영'), findsWidgets);
    expect(find.text('상담'), findsWidgets);
    expect(find.text('계획'), findsWidgets);
  });
}
