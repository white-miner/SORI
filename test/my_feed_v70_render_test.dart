import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/features/visit/home_visual_tokens.dart';
import 'package:sori/features/visit/widgets/ba_capture_carousel.dart';
import 'package:sori/features/visit/widgets/home_quick_action_row.dart';
import 'package:sori/features/visit/widgets/home_scheduler_strip.dart';
import 'package:sori/features/visit/widgets/management_case_card.dart';
import 'package:sori/models/ba_capture_session.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/visit_kernel/models/care_schedule_entry.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: HomeVisualTokens.canvasBg,
      body: child,
    ),
  );
}

BaCaptureSession _draft({
  required String id,
  String? before,
  String? after,
  String label = '',
}) {
  return BaCaptureSession(
    id: id,
    shopId: 'shop-1',
    sessionToken: 'token-$id',
    beforeImageUrl: before,
    afterImageUrl: after,
    label: label,
    createdAt: DateTime(2026, 9, 2, 9),
  );
}

void main() {
  group('② Quick Action — 컬러 헌법 (Q2a)', () {
    testWidgets('신규 고객은 보라 #8B5CF6, 재방문은 흰 배경 + 보더', (tester) async {
      await tester.pumpWidget(
        _host(
          HomeQuickActionRow(
            onNewCustomer: () {},
            onReturningCustomer: () {},
          ),
        ),
      );

      final materials = tester
          .widgetList<Material>(find.byType(Material))
          .where((m) => m.color != null)
          .toList();

      expect(
        materials.any((m) => m.color == HomeVisualTokens.quickNewFill),
        isTrue,
        reason: '신규 고객 버튼이 보라 토큰을 써야 한다',
      );
      expect(
        materials.any((m) => m.color == HomeVisualTokens.quickReturningFill),
        isTrue,
      );
      expect(HomeVisualTokens.quickNewFill, const Color(0xFF8B5CF6));
      expect(find.text('신규 고객'), findsOneWidget);
      expect(find.text('재방문 고객'), findsOneWidget);
    });

    testWidgets('케어 시작 Green이 신규 버튼에 재사용되지 않는다', (tester) async {
      await tester.pumpWidget(
        _host(
          HomeQuickActionRow(
            onNewCustomer: () {},
            onReturningCustomer: () {},
          ),
        ),
      );

      final colors = tester
          .widgetList<Material>(find.byType(Material))
          .map((m) => m.color)
          .toList();
      expect(colors.contains(HomeVisualTokens.careGreen), isFalse);
    });

    testWidgets('탭하면 각각의 라우팅 콜백이 발화한다', (tester) async {
      var newTaps = 0;
      var returningTaps = 0;
      await tester.pumpWidget(
        _host(
          HomeQuickActionRow(
            onNewCustomer: () => newTaps++,
            onReturningCustomer: () => returningTaps++,
          ),
        ),
      );

      await tester.tap(find.text('신규 고객'));
      await tester.tap(find.text('재방문 고객'));
      await tester.pump();

      expect(newTaps, 1);
      expect(returningTaps, 1);
    });
  });

  group('③ B/A 캐러셀 — 신호등 및 이관 애니메이션', () {
    testWidgets('첫 슬롯은 항상 새 촬영 카드다', (tester) async {
      await tester.pumpWidget(
        _host(
          BaCaptureCarousel(
            sessions: const [],
            onCapture: (_, _) {},
            onBind: (_) {},
            onDefer: (_) {},
          ),
        ),
      );

      expect(find.text('B/A 등록'), findsOneWidget);
      // 빈 상태에서도 ⊕ 두 개(Before/After)가 즉시 보인다.
      expect(find.byIcon(Icons.add_rounded), findsNWidgets(2));
    });

    testWidgets('Before만 찍힌 세션은 🔴와 "After 필요" 배지', (tester) async {
      await tester.pumpWidget(
        _host(
          BaCaptureCarousel(
            sessions: [_draft(id: 'a', before: 'https://x/b.webp')],
            onCapture: (_, _) {},
            onBind: (_) {},
            onDefer: (_) {},
          ),
        ),
      );

      expect(find.text('After 필요'), findsOneWidget);
      expect(find.text('1'), findsOneWidget, reason: '넛지 배지 카운트');
    });

    testWidgets('두 장 다 찍혔지만 차트 미연동이면 "고객 연결" 액션이 뜬다', (tester) async {
      BaCaptureSession? bound;
      await tester.pumpWidget(
        _host(
          BaCaptureCarousel(
            sessions: [
              _draft(
                id: 'a',
                before: 'https://x/b.webp',
                after: 'https://x/a.webp',
              ),
            ],
            onCapture: (_, _) {},
            onBind: (s) => bound = s,
            onDefer: (_) {},
          ),
        ),
      );

      expect(find.text('고객 연결'), findsOneWidget);
      await tester.tap(find.text('고객 연결'));
      await tester.pump();
      expect(bound?.id, 'a');
    });

    testWidgets('이관 중 카드는 320ms 동안 슬라이드 아웃한다 (Q3a)', (tester) async {
      final session = _draft(
        id: 'a',
        before: 'https://x/b.webp',
        after: 'https://x/a.webp',
        label: '최진실님',
      );

      await tester.pumpWidget(
        _host(
          BaCaptureCarousel(
            sessions: [session],
            transferringId: 'a',
            onCapture: (_, _) {},
            onBind: (_) {},
            onDefer: (_) {},
          ),
        ),
      );

      // index 0은 "새 촬영" 카드이므로, 이관 대상은 두 번째 카드다.
      final slides =
          tester.widgetList<AnimatedSlide>(find.byType(AnimatedSlide)).toList();
      expect(slides.length, 2);
      expect(slides.first.offset, Offset.zero, reason: '새 촬영 카드는 정지');

      final transferring = slides[1];
      expect(transferring.duration, HomeVisualTokens.baTransferDuration);
      expect(transferring.duration, const Duration(milliseconds: 320));
      expect(transferring.offset.dx, greaterThan(0), reason: '우측으로 이탈');

      // 이관 중에는 고객 연결 액션을 감춘다 (중복 바인딩 방지).
      expect(find.text('고객 연결'), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('밀어둔 세션도 넛지 카운트에 남는다', (tester) async {
      final deferred = BaCaptureSession(
        id: 'd',
        shopId: 'shop-1',
        sessionToken: 'token-d',
        beforeImageUrl: 'https://x/b.webp',
        deferredAt: DateTime(2026, 9, 2, 9),
        createdAt: DateTime(2026, 9, 2, 8),
      );

      await tester.pumpWidget(
        _host(
          BaCaptureCarousel(
            sessions: [deferred],
            onCapture: (_, _) {},
            onBind: (_) {},
            onDefer: (_) {},
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
    });
  });

  group('① 스케줄러 스트립', () {
    testWidgets('가장 가까운 일정을 "HH:mm 이름님 케어" 로 보여준다', (tester) async {
      final store = SoriStore();
      final today = DateTime.now();
      store.careScheduleEntries = [
        CareScheduleEntry(
          id: 'e1',
          shopId: store.shop.id,
          scheduledAt: DateTime(today.year, today.month, today.day, 12, 30),
          customerName: '김민정',
          careLabel: '상담예약',
        ),
      ];

      await tester.pumpWidget(
        _host(HomeSchedulerStrip(store: store, onTap: () {})),
      );

      expect(find.text('12:30 김민정님 상담예약'), findsOneWidget);
    });

    testWidgets('일정이 없으면 빈 상태 문구를 보여준다', (tester) async {
      final store = SoriStore();
      store.careScheduleEntries = [];

      await tester.pumpWidget(
        _host(HomeSchedulerStrip(store: store, onTap: () {})),
      );

      expect(find.text('오늘 예약된 일정이 없습니다'), findsOneWidget);
    });

    testWidgets('일정이 2건 이상이면 +N 칩이 붙는다', (tester) async {
      final store = SoriStore();
      final today = DateTime.now();
      store.careScheduleEntries = [
        CareScheduleEntry(
          id: 'e1',
          shopId: store.shop.id,
          scheduledAt: DateTime(today.year, today.month, today.day, 12, 30),
          customerName: '김민정',
          careLabel: '상담예약',
        ),
        CareScheduleEntry(
          id: 'e2',
          shopId: store.shop.id,
          scheduledAt: DateTime(today.year, today.month, today.day, 15),
          customerName: '최진실',
          careLabel: '웨딩케어',
        ),
      ];

      await tester.pumpWidget(
        _host(HomeSchedulerStrip(store: store, onTap: () {})),
      );

      expect(find.text('+1'), findsOneWidget);
    });
  });

  group('④ 관리 케이스 카드', () {
    testWidgets('회차 · 케어명 · 고객 키워드가 모두 보인다', (tester) async {
      final chart = CustomerChart(
        id: 'c1',
        shopId: 'shop-1',
        customerId: 'cus-1',
        visitNumber: 3,
        careName: '스페셜 웨딩 케어',
        feedAge: 38,
        feedGenderLabel: '여성',
        skinSensitivity: '민감',
        concernChips: const ['부종', '순환'],
      );

      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: ManagementCaseCard(
              chart: chart,
              bookmarked: false,
              onBookmark: () {},
              onExpand: () {},
            ),
          ),
        ),
      );

      expect(find.text('3 회차'), findsOneWidget);
      expect(find.text('스페셜 웨딩 케어'), findsOneWidget);
      expect(find.text('Before'), findsWidgets);
      expect(find.text('After'), findsWidgets);

      final caption = tester.widget<Text>(
        find.textContaining('만 38세').first,
      );
      expect(caption.data, contains('여성'));
      expect(caption.data, contains('민감'));
      expect(caption.data, contains('부종'));
    });

    testWidgets('북마크 상태가 아이콘에 반영되고 탭이 전달된다', (tester) async {
      var taps = 0;
      final chart = CustomerChart(
        id: 'c1',
        shopId: 'shop-1',
        customerId: 'cus-1',
        visitNumber: 1,
        careName: '테스트 케어',
      );

      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: ManagementCaseCard(
              chart: chart,
              bookmarked: true,
              onBookmark: () => taps++,
              onExpand: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.bookmark_rounded));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('케어명이 비면 "관리 케이스"로 폴백한다', (tester) async {
      final chart = CustomerChart(
        id: 'c1',
        shopId: 'shop-1',
        customerId: 'cus-1',
        visitNumber: 1,
        careName: '',
      );

      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: ManagementCaseCard(
              chart: chart,
              bookmarked: false,
              onBookmark: () {},
              onExpand: () {},
            ),
          ),
        ),
      );

      expect(find.text('관리 케이스'), findsOneWidget);
    });
  });
}
