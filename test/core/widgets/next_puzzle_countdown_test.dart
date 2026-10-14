import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/widgets/next_puzzle_countdown.dart';
import 'package:winklo/domain/play_period.dart';

void main() {
  testWidgets('counts down to the next local midnight', (tester) async {
    var now = DateTime(2026, 10, 14, 17, 48);
    await tester.pumpWidget(
      MaterialApp(
        home: NextPuzzleCountdown(period: PlayPeriod.daily, clock: () => now),
      ),
    );
    expect(find.text('New puzzle in 6h 12m'), findsOneWidget);

    // The text changes when the rounded-up minute does.
    now = DateTime(2026, 10, 14, 17, 48, 59);
    await tester.pump(const Duration(seconds: 59));
    expect(find.text('New puzzle in 6h 12m'), findsOneWidget);
    now = DateTime(2026, 10, 14, 17, 49, 0, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('New puzzle in 6h 11m'), findsOneWidget);
  });

  testWidgets('says the puzzle is ready at midnight', (tester) async {
    var now = DateTime(2026, 10, 14, 23, 59, 30);
    await tester.pumpWidget(
      MaterialApp(
        home: NextPuzzleCountdown(period: PlayPeriod.daily, clock: () => now),
      ),
    );
    expect(find.text('New puzzle in 1m'), findsOneWidget);

    now = DateTime(2026, 10, 15, 0, 0, 0, 1);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text(AppStrings.newPuzzleReady), findsOneWidget);
  });

  testWidgets('stops its timer when removed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NextPuzzleCountdown(
          period: PlayPeriod.daily,
          clock: () => DateTime(2026, 10, 14, 12),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    // A pending timer would fail the test here.
  });
}
