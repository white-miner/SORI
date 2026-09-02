import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/features/program/widgets/program_board.dart';
import 'package:sori/features/visit/home_visual_tokens.dart';
import 'package:sori/models/program_sales.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

void main() {
  testWidgets('Collapsed 카드에는 최고가 외 가격 문자열이 없다', (tester) async {
    final demo = ProgramDemoSeed.forShop('shop-demo');
    final board = ProgramCategoryBoard.assemble(
      category: demo.categories.first,
      allPackages: demo.packages,
    );

    await tester.pumpWidget(
      _host(
        ProgramCategoryCard(
          board: board,
          expanded: false,
          selectedIds: const [],
          onToggleExpand: () {},
          onToggleCheck: (_) {},
        ),
      ),
    );

    expect(find.text('3,000,000'), findsOneWidget);
    expect(find.text('1,500,000'), findsNothing);
    expect(find.text('1,000,000'), findsNothing);
    expect(find.text('B패키지  6회'), findsNothing);
  });

  testWidgets('Expand 해도 앵커가 맨 위에 남는다', (tester) async {
    final demo = ProgramDemoSeed.forShop('shop-demo');
    final board = ProgramCategoryBoard.assemble(
      category: demo.categories.first,
      allPackages: demo.packages,
    );

    await tester.pumpWidget(
      _host(
        ProgramCategoryCard(
          board: board,
          expanded: true,
          selectedIds: const [],
          onToggleExpand: () {},
          onToggleCheck: (_) {},
        ),
      ),
    );

    final a = tester.getTopLeft(find.text('A패키지  10회')).dy;
    final b = tester.getTopLeft(find.text('B패키지  6회')).dy;
    expect(a, lessThan(b));
    expect(find.text('3,000,000'), findsOneWidget);
    expect(find.text('1,500,000'), findsOneWidget);
  });

  test('closer 토큰은 charcoal 이며 green/violet 이 아니다', () {
    expect(HomeVisualTokens.programCloserFill, const Color(0xFF1C1C1E));
    expect(HomeVisualTokens.programCloserFill, isNot(HomeVisualTokens.careGreen));
    expect(HomeVisualTokens.programCloserFill, isNot(HomeVisualTokens.quickNewFill));
    expect(
      HomeVisualTokens.programExpandDuration,
      const Duration(milliseconds: 280),
    );
  });
}
