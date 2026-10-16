import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/game_day_record.dart';
import 'package:winklo/domain/entities/game_history.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/usecases/load_game_history.dart';
import 'package:winklo/features/achievements/view/badges_screen.dart';

class _MockLoadHistory extends Mock implements LoadGameHistory {}

/// Zip cleared the 7 days to 15 Oct 2026 (a 7-day run, under a minute once),
/// and one Sudoku.
GameHistory _history() => GameHistory(
  days: [
    for (var d = 9; d <= 15; d++)
      GameDayRecord(
        gameId: GameIds.zip,
        playId: '202610$d',
        timeSeconds: d == 15 ? 45 : 80,
        usedHints: true,
      ),
    const GameDayRecord(
      gameId: GameIds.sudoku,
      playId: '20261015',
      timeSeconds: 300,
    ),
  ],
  streaks: const {
    GameIds.zip: GameStreak(gameId: GameIds.zip, current: 7, longest: 7),
  },
  today: DateTime(2026, 10, 15),
);

void main() {
  late _MockLoadHistory load;

  setUp(() {
    load = _MockLoadHistory();
    when(
      () => load(refreshRemote: any(named: 'refreshRemote')),
    ).thenAnswer((_) async => _history());
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepositoryProvider<LoadGameHistory>.value(
        value: load,
        child: MaterialApp(theme: buildAppTheme(), home: const BadgesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder labelled(String label) => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
  );

  testWidgets('a ladder per game and the special badges', (tester) async {
    await pump(tester);

    expect(find.text(AppStrings.achievementsTitle), findsOneWidget);
    // first Zip, first Sudoku, 7-day Zip, under a minute.
    expect(find.text(AppStrings.achievementsProgress(4, 16)), findsOneWidget);
    for (final game in [
      AppStrings.zipTitle,
      AppStrings.pathWordsTitle,
      AppStrings.sudokuTitle,
    ]) {
      expect(find.text(game), findsOneWidget);
    }
    expect(find.text(AppStrings.achievementLadderFirst), findsNWidgets(3));
    expect(find.text(AppStrings.achievementLadderDays(100)), findsNWidgets(3));
    expect(find.text(AppStrings.achievementsSpecial), findsOneWidget);
    expect(find.text(AppStrings.achievementPerfectDayTitle), findsOneWidget);
    expect(
      find.text(AppStrings.achievementZipUnderMinuteTitle),
      findsOneWidget,
    );
    expect(find.text(AppStrings.achievementCurrentStreak(7)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen readers hear earned and locked badges', (tester) async {
    await pump(tester);

    final earned = tester.widget<Semantics>(labelled('7-day Zip streak'));
    expect(earned.properties.value, isNull);
    final locked = tester.widget<Semantics>(labelled('30-day Zip streak'));
    expect(
      locked.properties.value,
      '${AppStrings.achievementLocked}. Clear Zip 30 days in a row',
    );
    final special = tester.widget<Semantics>(
      labelled(AppStrings.achievementPerfectDayTitle),
    );
    expect(special.properties.value, startsWith(AppStrings.achievementLocked));
  });

  testWidgets('a failed load offers Retry', (tester) async {
    when(
      () => load(refreshRemote: any(named: 'refreshRemote')),
    ).thenThrow(Exception('offline'));
    await pump(tester);

    expect(find.text(AppStrings.statsFailed), findsOneWidget);
    when(
      () => load(refreshRemote: any(named: 'refreshRemote')),
    ).thenAnswer((_) async => _history());
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.achievementsProgress(4, 16)), findsOneWidget);
  });
}
