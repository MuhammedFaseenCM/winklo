import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/features/results/results_args.dart';
import 'package:winklo/features/results/view/level_results_view.dart';

ResultsArgs args({
  required LevelResultInfo level,
  int seconds = 24,
  bool improved = false,
}) => ResultsArgs(
  title: 'Level 7 cleared',
  subtitle: '',
  timeSeconds: seconds,
  improved: improved,
  points: 0,
  gameId: 'zip',
  usedHints: level.usedHints,
  hadMistakes: false,
  hintPenaltySeconds: 0,
  local: LocalResultInfo(
    kind: LocalResultKind.level,
    label: 'Level 7 · Ink',
    bestSeconds: seconds,
    againLocation: '/zip?mode=level&level=zip_1_07',
    level: level,
  ),
);

Future<void> pump(WidgetTester tester, ResultsArgs value) =>
    tester.pumpWidget(MaterialApp(home: LevelResultsView(args: value)));

void main() {
  testWidgets('shows the time, the target and every goal', (tester) async {
    await pump(
      tester,
      args(
        level: const LevelResultInfo(
          runStars: 3,
          bestStars: 3,
          usedHints: false,
          targetSeconds: 30,
          nextLocation: '/zip?mode=level&level=zip_1_08',
        ),
      ),
    );
    expect(find.text('Level 7 cleared'), findsOneWidget);
    expect(find.text('Level 7 · Ink'), findsOneWidget);
    expect(find.text('0:24 · Target 0:30'), findsOneWidget);
    expect(find.text('Clear the board'), findsOneWidget);
    expect(find.text('No hints'), findsOneWidget);
    expect(find.text('0:30 or less'), findsOneWidget);
    expect(find.text('Next level'), findsOneWidget);
    expect(find.text('Replay'), findsOneWidget);
  });

  testWidgets('a missed goal says how to earn it', (tester) async {
    await pump(
      tester,
      args(
        level: const LevelResultInfo(
          runStars: 2,
          bestStars: 2,
          usedHints: true,
          targetSeconds: 30,
        ),
      ),
    );
    expect(find.text('Replay without hints for this star'), findsOneWidget);
    expect(find.text('More worlds coming soon'), findsOneWidget);
  });

  testWidgets('says what improved, and names the next world', (tester) async {
    await pump(
      tester,
      args(
        improved: true,
        level: const LevelResultInfo(
          runStars: 3,
          bestStars: 3,
          previousStars: 2,
          usedHints: false,
          targetSeconds: 30,
          nextLocation: '/zip?mode=level&level=zip_2_01',
          nextWorldTheme: 'metro',
        ),
      ),
    );
    expect(find.text('New best · 2 → 3 stars'), findsOneWidget);
    expect(find.text('Open Metro'), findsOneWidget);
  });
}
