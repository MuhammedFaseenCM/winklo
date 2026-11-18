import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/widgets/level_goals.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    int? target = 30,
    bool usedHints = false,
    int elapsedMs = 0,
    DateTime? resumedAt,
    bool cleared = false,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: LevelGoalsBar(
              targetSeconds: target,
              usedHints: usedHints,
              elapsedMs: elapsedMs,
              resumedAt: resumedAt,
              cleared: cleared,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('before the clock runs: every goal is still possible', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Clear the board'), findsOneWidget);
    expect(find.text('No hints'), findsOneWidget);
    expect(find.text('0:30 or less'), findsOneWidget);
    expect(find.bySemanticsLabel('No hints, still possible'), findsOneWidget);
  });

  testWidgets('counts down while the clock runs', (tester) async {
    await pump(tester, elapsedMs: 12000);
    // Paused at 12s: the countdown shows what is left.
    expect(find.text('0:18 left'), findsOneWidget);
  });

  testWidgets('a hint loses No hints; past the target loses the time', (
    tester,
  ) async {
    await pump(tester, usedHints: true, elapsedMs: 31000);
    expect(find.bySemanticsLabel('No hints, missed'), findsOneWidget);
    expect(find.bySemanticsLabel('0:30 or less, missed'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Clear the board, still possible'),
      findsOneWidget,
    );
  });

  testWidgets('a clear earns what is still in reach', (tester) async {
    await pump(tester, usedHints: true, elapsedMs: 20000, cleared: true);
    expect(find.bySemanticsLabel('Clear the board, earned'), findsOneWidget);
    expect(find.bySemanticsLabel('No hints, missed'), findsOneWidget);
    expect(find.bySemanticsLabel('0:30 or less, earned'), findsOneWidget);
  });

  testWidgets('no target, no time goal', (tester) async {
    await pump(tester, target: null);
    expect(find.textContaining('or less'), findsNothing);
    expect(find.textContaining('left'), findsNothing);
  });

  testWidgets('large text lays out without an exception', (tester) async {
    await pump(tester, textScale: 2, elapsedMs: 5000);
    expect(tester.takeException(), isNull);
  });
}
