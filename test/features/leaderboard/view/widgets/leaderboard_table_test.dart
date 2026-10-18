import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/features/leaderboard/view/widgets/leaderboard_table.dart';

LeaderboardEntry _entry({
  int rank = 4,
  int seconds = 75,
  bool? usedHints,
  bool? hadMistakes,
  int? streak,
  int? days,
}) => LeaderboardEntry(
  uid: 'u$rank',
  displayName: 'Ada',
  timeSeconds: seconds,
  updatedAt: DateTime.utc(2026, 10, 15),
  rank: rank,
  usedHints: usedHints,
  hadMistakes: hadMistakes,
  currentStreak: streak,
  daysCleared: days,
);

/// A [Semantics] widget labelled [label] (icons carry their meaning there).
Finder _labelled(String label) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == label,
);

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('header columns follow the board', (tester) async {
    await _pump(
      tester,
      const LeaderboardTableHeader(period: LeaderboardPeriod.daily),
    );
    expect(find.text(AppStrings.leaderboardColumnPlayer), findsOneWidget);
    expect(find.text(AppStrings.leaderboardColumnTime), findsOneWidget);
    expect(find.text(AppStrings.leaderboardColumnDays), findsNothing);

    await _pump(
      tester,
      const LeaderboardTableHeader(period: LeaderboardPeriod.weekly),
    );
    expect(find.text(AppStrings.leaderboardColumnDays), findsOneWidget);
    expect(find.text(AppStrings.leaderboardColumnTotal), findsOneWidget);

    await _pump(
      tester,
      const LeaderboardTableHeader(period: LeaderboardPeriod.allTime),
    );
    expect(find.text(AppStrings.leaderboardColumnBest), findsOneWidget);
  });

  testWidgets('a daily row: rank, name, time and clean-run icons', (
    tester,
  ) async {
    await _pump(
      tester,
      LeaderboardTableRow(
        entry: _entry(usedHints: false, hadMistakes: false, streak: 5),
        period: LeaderboardPeriod.daily,
        gameId: GameIds.sudoku,
        isYou: false,
      ),
    );
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('1:15'), findsOneWidget);
    expect(_labelled(AppStrings.leaderboardNoHintChip), findsOneWidget);
    expect(_labelled(AppStrings.leaderboardNoMistakesChip), findsOneWidget);
    expect(_labelled(AppStrings.streakLabel(5)), findsOneWidget);
    expect(tester.getSize(find.byType(LeaderboardTableRow)).height, 48);
  });

  testWidgets('Flawless is Sudoku only; no icons off the daily board', (
    tester,
  ) async {
    await _pump(
      tester,
      LeaderboardTableRow(
        entry: _entry(hadMistakes: false),
        period: LeaderboardPeriod.daily,
        gameId: GameIds.zip,
        isYou: false,
      ),
    );
    expect(_labelled(AppStrings.leaderboardNoMistakesChip), findsNothing);

    await _pump(
      tester,
      LeaderboardTableRow(
        entry: _entry(usedHints: false, streak: 5),
        period: LeaderboardPeriod.allTime,
        gameId: GameIds.zip,
        isYou: false,
      ),
    );
    expect(_labelled(AppStrings.leaderboardNoHintChip), findsNothing);
    expect(_labelled(AppStrings.streakLabel(5)), findsNothing);
  });

  testWidgets('a weekly row shows days and the week total', (tester) async {
    await _pump(
      tester,
      LeaderboardTableRow(
        entry: _entry(seconds: 372, days: 5),
        period: LeaderboardPeriod.weekly,
        gameId: GameIds.zip,
        isYou: false,
      ),
    );
    expect(find.text('5'), findsOneWidget);
    expect(find.text('6:12'), findsOneWidget);
  });

  testWidgets('a long name ellipsises instead of overflowing', (tester) async {
    tester.view.physicalSize = const Size(320, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(
      tester,
      LeaderboardTableRow(
        entry: LeaderboardEntry(
          uid: 'x',
          displayName: 'Rahul Menon Kuttikkattil Parambil',
          timeSeconds: 3725,
          updatedAt: DateTime.utc(2026),
          rank: 12,
          usedHints: false,
          currentStreak: 30,
        ),
        period: LeaderboardPeriod.daily,
        gameId: GameIds.zip,
        isYou: true,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('big text scales the time down instead of clipping it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            body: Column(
              children: [
                const LeaderboardTableHeader(period: LeaderboardPeriod.weekly),
                LeaderboardTableRow(
                  entry: _entry(seconds: 8432, days: 7),
                  period: LeaderboardPeriod.weekly,
                  gameId: GameIds.zip,
                  isYou: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final time = tester.renderObject<RenderParagraph>(find.text('140:32'));
    // Laid out at its full width (not cut), then fitted into the column.
    expect(
      time.size.width,
      greaterThanOrEqualTo(time.getMaxIntrinsicWidth(double.infinity) - 0.5),
    );
    expect(
      tester.getRect(find.text('140:32')).right,
      lessThanOrEqualTo(tester.getRect(find.byType(LeaderboardTableRow)).right),
    );
  });

  testWidgets('tapping a row calls onTap', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      LeaderboardTableRow(
        entry: _entry(),
        period: LeaderboardPeriod.daily,
        gameId: GameIds.zip,
        isYou: false,
        onTap: () => taps++,
      ),
    );
    await tester.tap(find.text('Ada'));
    expect(taps, 1);
  });
}
