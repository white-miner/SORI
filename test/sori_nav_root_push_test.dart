import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/utils/sori_nav.dart';

void main() {
  testWidgets('pushRootPage stacks above shell FloatingPillNav', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: const Center(child: Text('shell-body')),
              bottomNavigationBar: Container(
                height: 64,
                color: Colors.blue,
                child: const Center(child: Text('floating-pill')),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  pushRootPage<void>(
                    context,
                    Scaffold(
                      appBar: AppBar(
                        title: const Text('detail'),
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      body: const Center(child: Text('detail-body')),
                    ),
                  );
                },
                child: const Icon(Icons.open_in_new),
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('floating-pill'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('detail-body'), findsOneWidget);
    expect(find.text('floating-pill'), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('shell-body'), findsOneWidget);
    expect(find.text('floating-pill'), findsOneWidget);
  });
}
