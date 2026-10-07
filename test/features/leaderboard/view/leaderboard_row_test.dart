import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/features/leaderboard/view/widgets/leaderboard_row.dart';

LeaderboardEntry entry(
  int rank, {
  bool? usedHints,
  bool? hadMistakes,
  int? currentStreak,
}) => LeaderboardEntry(
  uid: 'u$rank',
  displayName: 'Player $rank',
  timeSeconds: 30,
  updatedAt: DateTime.utc(2026, 9, 24),
  rank: rank,
  usedHints: usedHints,
  hadMistakes: hadMistakes,
  currentStreak: currentStreak,
);

void main() {
  testWidgets('rank 1 shows gold medal asset, not numeral', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: LeaderboardRow(
            entry: entry(1),
            timeLabel: '0:30',
            isYou: false,
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('rank 4 shows numeral', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: LeaderboardRow(entry: entry(4), timeLabel: '0:40', isYou: true),
        ),
      ),
    );
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('ranks 1, 2, 3 have thicker borders than standard rows', (
    tester,
  ) async {
    for (final rank in [1, 2, 3]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: LeaderboardRow(
              entry: entry(rank),
              timeLabel: '0:30',
              isYou: false,
            ),
          ),
        ),
      );
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.width, greaterThanOrEqualTo(2.0));
    }
  });

  testWidgets('daily clean-run chips show for no-hint and no-mistakes sudoku', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: LeaderboardRow(
            entry: entry(4, usedHints: false, hadMistakes: false),
            timeLabel: '0:40',
            isYou: false,
            showCleanRunChips: true,
            gameId: GameIds.sudoku,
          ),
        ),
      ),
    );
    expect(find.text(AppStrings.leaderboardNoHintChip), findsOneWidget);
    expect(find.text(AppStrings.leaderboardNoMistakesChip), findsOneWidget);
  });

  testWidgets(
    'no-mistakes chip hidden for non-sudoku even when hadMistakes false',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: LeaderboardRow(
              entry: entry(4, usedHints: false, hadMistakes: false),
              timeLabel: '0:40',
              isYou: false,
              showCleanRunChips: true,
              gameId: GameIds.zip,
            ),
          ),
        ),
      );
      expect(find.text(AppStrings.leaderboardNoHintChip), findsOneWidget);
      expect(find.text(AppStrings.leaderboardNoMistakesChip), findsNothing);
    },
  );

  testWidgets('chips hidden when showCleanRunChips is false', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: LeaderboardRow(
            entry: entry(
              4,
              usedHints: false,
              hadMistakes: false,
              currentStreak: 5,
            ),
            timeLabel: '0:40',
            isYou: false,
            showCleanRunChips: false,
            gameId: GameIds.sudoku,
          ),
        ),
      ),
    );
    expect(find.text(AppStrings.leaderboardNoHintChip), findsNothing);
    expect(find.text(AppStrings.leaderboardNoMistakesChip), findsNothing);
    expect(find.text(AppStrings.streakLabel(5)), findsNothing);
  });

  testWidgets('streak chip shows when currentStreak >= 2', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: LeaderboardRow(
            entry: entry(4, currentStreak: 3),
            timeLabel: '0:40',
            isYou: false,
            showCleanRunChips: true,
            gameId: GameIds.zip,
          ),
        ),
      ),
    );
    expect(find.text(AppStrings.streakLabel(3)), findsOneWidget);
  });

  testWidgets('streak chip hidden when currentStreak is 1', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: LeaderboardRow(
            entry: entry(4, currentStreak: 1),
            timeLabel: '0:40',
            isYou: false,
            showCleanRunChips: true,
            gameId: GameIds.zip,
          ),
        ),
      ),
    );
    expect(find.text(AppStrings.streakLabel(1)), findsNothing);
  });

  testWidgets('long name keeps full width; chips sit on second line', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: LeaderboardRow(
              entry: LeaderboardEntry(
                uid: 'u',
                displayName: 'Very Long Display Name For Testing Truncation',
                timeSeconds: 30,
                updatedAt: DateTime.utc(2026, 9, 24),
                rank: 4,
                usedHints: false,
                hadMistakes: false,
              ),
              timeLabel: '0:40',
              isYou: true,
              showCleanRunChips: true,
              gameId: GameIds.sudoku,
            ),
          ),
        ),
      ),
    );
    expect(find.text(AppStrings.youLabel), findsOneWidget);
    expect(find.text(AppStrings.leaderboardNoHintChip), findsOneWidget);
    expect(find.text(AppStrings.leaderboardNoMistakesChip), findsOneWidget);
    expect(
      find.text('Very Long Display Name For Testing Truncation'),
      findsOneWidget,
    );
  });
}
