// S3-0 특성 테스트: 후기 링크 화면(/review?token=)과 후기 저장 경로.
//
// 지금은 ① 토큰을 스토어 메모리의 차트 feedbackToken 에서 찾고 ② 고객 이름을
// 가리지 않고 보여 주며 ③ 저장은 markNaverRegistered 로 별점 없이 바로
// "게시 + 네이버 등록"이 된다 (실패 시 1회 재시도 후 예외).
// 보안 S3 PR 3-6에서 get_review_context / 토큰 저장 RPC(M1b)로 바뀌면
// ①② 기대값을 그 PR에서 고친다. ③의 "별점 없이 게시 + 네이버 등록" 의미는 M1b가 그대로 옮긴다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/models/customer_review.dart';
import 'package:sori/models/session_user.dart';
import 'package:sori/services/pending_review_return.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/customer_review_page.dart';
import 'package:sori/views/ikea_review_composer_page.dart';

class _SpyRepository extends MemorySoriRepository {
  _SpyRepository({this.failNaver = false});

  final bool failNaver;
  final List<Map<String, String?>> naverCalls = [];

  @override
  Future<CustomerReview?> markNaverRegistered({
    required String chartId,
    String? composedText,
  }) async {
    naverCalls.add({'chartId': chartId, 'composedText': composedText});
    if (failNaver) throw StateError('rls denied');
    return super.markNaverRegistered(
      chartId: chartId,
      composedText: composedText,
    );
  }
}

CustomerChart _openFeedbackLine(SoriStore store) {
  return store.saveChartAndConfirmVisit(
    customerId: '1',
    visitNumber: 2,
    customChartNo: 'S3-RV',
    careName: '재생케어',
    treatmentSummary: '2회차',
    directorInsight: '안정',
    concernChips: const ['건조/장벽'],
    firstVisitFearChips: const [],
    revisitFeedbackChips: const [],
  );
}

Future<void> _pumpPage(
  WidgetTester tester,
  SoriStore store,
  String token,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CustomerReviewPage(store: store, token: token),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('S3-0 후기 링크 화면 특성', () {
    testWidgets('메모리 차트의 feedbackToken 이면 고객 전체 이름과 카카오 로그인 안내', (
      tester,
    ) async {
      final store = SoriStore(repository: _SpyRepository());
      final chart = _openFeedbackLine(store);
      final token = chart.feedbackToken!;

      await _pumpPage(tester, store, token);

      expect(store.findChartByToken(token)?.id, chart.id);
      expect(find.text('김민지님,'), findsOneWidget);
      expect(find.text('카카오로 1초 로그인'), findsOneWidget);
      expect(PendingReviewReturn.peek(), token);
      PendingReviewReturn.take();
    });

    testWidgets('메모리에 없는 토큰은 "유효하지 않은 고객 링크"', (tester) async {
      final store = SoriStore(repository: _SpyRepository());

      await _pumpPage(tester, store, 'unknown-token-xyz');

      expect(find.text('유효하지 않은 고객 링크입니다'), findsOneWidget);
      expect(find.text('카카오로 1초 로그인'), findsNothing);
      PendingReviewReturn.take();
    });

    testWidgets('빈 토큰도 "유효하지 않은 고객 링크"이고 토큰을 저장하지 않는다', (tester) async {
      PendingReviewReturn.take();
      final store = SoriStore(repository: _SpyRepository());

      await _pumpPage(tester, store, '   ');

      expect(find.text('유효하지 않은 고객 링크입니다'), findsOneWidget);
      expect(PendingReviewReturn.peek(), isNull);
    });

    testWidgets('스토어 세션이 있으면 로그인 안내 대신 후기 작성 화면을 바로 연다', (tester) async {
      final store = SoriStore(repository: _SpyRepository());
      final chart = _openFeedbackLine(store);
      store.beginSocialLogin(
        provider: SocialProvider.kakao,
        name: '김민지',
        phone: '010-1234-5678',
      );

      await _pumpPage(tester, store, chart.feedbackToken!);

      expect(find.byType(IkeaReviewComposerPage), findsOneWidget);
      expect(find.text('카카오로 1초 로그인'), findsNothing);
      PendingReviewReturn.take();
    });
  });

  group('S3-0 후기 저장(markNaverRegistered) 특성', () {
    test('별점 없이 차트 id 와 문구만으로 저장하고 결과는 게시 + 네이버 등록', () async {
      final repo = _SpyRepository();
      final store = SoriStore(repository: repo);
      final chart = _openFeedbackLine(store);

      final review = await store.markNaverRegistered(
        chartId: chart.id,
        composedText: '피부가 편안해졌어요',
      );

      expect(repo.naverCalls, [
        {'chartId': chart.id, 'composedText': '피부가 편안해졌어요'},
      ]);
      expect(review, isNotNull);
      expect(review!.naverRegistered, isTrue);
      expect(review.status, ReviewStatus.published);
      expect(review.naverPublishStatus, NaverPublishStatus.registered);
      final cached = store.reviewForChart(chart.id);
      expect(cached?.status, ReviewStatus.published);
      expect(cached?.naverRegistered, isTrue);
    });

    test('저장소가 실패하면 1회 재시도(총 2번) 후 예외를 던진다', () async {
      final repo = _SpyRepository(failNaver: true);
      final store = SoriStore(repository: repo);
      final chart = _openFeedbackLine(store);

      await expectLater(
        store.markNaverRegistered(chartId: chart.id, composedText: 'x'),
        throwsA(isA<StateError>()),
      );
      expect(repo.naverCalls, hasLength(2));
    });
  });
}
