import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/omni_compose_category.dart';
import 'package:sori/models/session_user.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/post_first_creation_page.dart';
import 'package:sori/widgets/unified_compose_sheet.dart';

void main() {
  late SoriStore store;

  setUp(() async {
    store = SoriStore.instance;
    await store.bootstrap(repository: MemorySoriRepository());
    store.session = const SessionUser(
      role: UserRole.director,
      name: '김원장',
      phone: '010-1234-5678',
      provider: SocialProvider.kakao,
      onboardingComplete: true,
      shopSetupComplete: true,
      activeMode: UserRole.director,
    );
  });

  Future<void> pumpComposer(
    WidgetTester tester, {
    OmniComposeCategory? initialCategory,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PostFirstCreationPage(
          store: store,
          initialCategory: initialCategory,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens with Whisper default and switches adaptive forms', (tester) async {
    await pumpComposer(tester);

    expect(find.text('무엇을 공유할까요?'), findsOneWidget);
    expect(find.byKey(const Key('omni-whisper-body')), findsOneWidget);

    await tester.tap(find.byKey(const Key('omni-cat-baShare')));
    await tester.pumpAndSettle();
    expect(find.text('Before'), findsOneWidget);
    expect(find.text('After'), findsOneWidget);
    expect(find.text('기존 차트 연동'), findsOneWidget);
    expect(find.text('AI 요약 생성'), findsOneWidget);

    await tester.tap(find.byKey(const Key('omni-cat-seminar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('omni-seminar-price')), findsOneWidget);
    expect(find.text('커리큘럼'), findsWidgets);
  });

  testWidgets('initialCategory mentorAsk shows mentor form', (tester) async {
    await pumpComposer(tester, initialCategory: OmniComposeCategory.mentorAsk);
    expect(find.byKey(const Key('omni-mentor-body')), findsOneWidget);
    expect(find.text('멘토 요청'), findsWidgets);
  });

  testWidgets('empty submit shows validation snackbar', (tester) async {
    await pumpComposer(tester);

    await tester.tap(find.byKey(const Key('omni-composer-submit')));
    await tester.pumpAndSettle();
    expect(find.text('제목이나 내용을 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('B/A submit without photos shows photo snackbar', (tester) async {
    await pumpComposer(tester);
    await tester.tap(find.text('전후(B/A)'));
    await tester.pumpAndSettle();
    expect(find.text('Before'), findsOneWidget);

    await tester.tap(find.byKey(const Key('omni-composer-submit')));
    await tester.pumpAndSettle();
    expect(find.text('B/A 공유는 비포/애프터 사진이 필요합니다.'), findsOneWidget);
  });

  testWidgets('seminar submit without fee shows price snackbar', (tester) async {
    await pumpComposer(tester);
    await tester.tap(find.text('세미나'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('omni-seminar-title')), '원데이 클래스');
    await tester.enterText(find.byKey(const Key('omni-seminar-price')), '');
    await tester.tap(find.byKey(const Key('omni-composer-submit')));
    await tester.pumpAndSettle();
    expect(find.text('세미나 수강료를 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('whisper submit posts via store and pops', (tester) async {
    await pumpComposer(tester);
    await tester.enterText(
      find.byKey(const Key('omni-whisper-body')),
      '위스퍼 본문입니다',
    );
    await tester.tap(find.byKey(const Key('omni-composer-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(PostFirstCreationPage), findsNothing);
  });

  testWidgets('C6 quick compose sheet shows B/A seminar tip mentor chips',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showQuickComposeSheet(
                  context,
                  store: store,
                  isDirector: true,
                  onDirectorOnly: () {},
                ),
                child: const Text('open-sheet'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-sheet'));
    await tester.pumpAndSettle();

    expect(find.text('빠른 등록'), findsOneWidget);
    expect(find.byKey(const Key('quick-compose-baShare')), findsOneWidget);
    expect(find.byKey(const Key('quick-compose-seminar')), findsOneWidget);
    expect(find.byKey(const Key('quick-compose-tipDevice')), findsOneWidget);
    expect(find.byKey(const Key('quick-compose-tipProduct')), findsOneWidget);
    expect(find.byKey(const Key('quick-compose-mentorAsk')), findsOneWidget);
    expect(find.byKey(const Key('quick-compose-mentorOffer')), findsOneWidget);

    await tester.tap(find.byKey(const Key('quick-compose-tipDevice')));
    await tester.pumpAndSettle();
    expect(find.byType(PostFirstCreationPage), findsOneWidget);
    expect(find.text('기기명'), findsOneWidget);
  });
}
