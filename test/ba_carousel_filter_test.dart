import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/features/visit/home_visual_tokens.dart';
import 'package:sori/features/visit/widgets/ba_capture_carousel.dart';
import 'package:sori/models/ba_capture_session.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: HomeVisualTokens.canvasBg,
      body: child,
    ),
  );
}

BaCaptureSession _session({
  required String id,
  required String label,
  required bool complete,
}) {
  return BaCaptureSession(
    id: id,
    shopId: 'shop-1',
    sessionToken: 'token-$id',
    beforeImageUrl: 'https://x/$id-b.webp',
    afterImageUrl: complete ? 'https://x/$id-a.webp' : null,
    chartId: complete ? 'chart-$id' : null,
    label: label,
    createdAt: DateTime(2026, 9, 2, 9),
  );
}

void main() {
  testWidgets('히스토리는 한 줄이며 NEW가 항상 첫 칸이다', (tester) async {
    BaCaptureSession? opened;
    await tester.pumpWidget(_host(BaCaptureCarousel(
      sessions: [_session(id: 'done', label: '완성케어', complete: true)],
      onCapture: (_, _) {}, onBind: (_) {}, onDefer: (_) {},
      onOpen: (s) => opened = s,
    )));
    expect(find.text('B&A 히스토리'), findsOneWidget);
    expect(tester.getTopLeft(find.text('NEW')).dx,
      lessThan(tester.getTopLeft(find.text('완성케어')).dx));
    await tester.tap(find.text('완성케어'));
    expect(opened?.id, 'done');
  });
  testWidgets('NEW를 열고 닫아도 촬영·연결이 발생하지 않는다', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_host(BaCaptureCarousel(
      sessions: const [], pending: _session(id: 'pending', label: '', complete: false),
      onCapture: (_, _) => calls++, onBind: (_) => calls++, onDefer: (_) {}, onOpen: (_) {},
    )));
    await tester.tap(find.text('NEW'));
    await tester.pumpAndSettle();
    expect(find.text('차트 작성'), findsOneWidget);
    expect(calls, 0);
    final context = tester.element(find.text('차트 작성'));
    Navigator.pop(context);
    await tester.pumpAndSettle();
    expect(find.text('작성 중'), findsOneWidget);
    expect(calls, 0);
  });
}
