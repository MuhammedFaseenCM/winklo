import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/game_day_record.dart';
import 'package:winklo/domain/entities/game_history.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/usecases/load_game_history.dart';
import 'package:winklo/features/stats/view/stats_screen.dart';
import 'package:winklo/features/stats/view/widgets/best_trend_chart.dart';
import 'package:winklo/features/stats/view/widgets/time_histogram_chart.dart';

class _MockLoadHistory extends Mock implements LoadGameHistory {}

final _today = DateTime(2026, 10, 15);

String _id(DateTime d) =>
    '${d.year}${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

/// Zip: 29 clears over the last 40 days (a gap now and then, some hints).
/// Path Words: three clears in September. Sudoku: none.
GameHistory sampleHistory({bool remoteFailed = false}) {
  final days = <GameDayRecord>[];
  for (var i = 39; i >= 0; i--) {
    if (i % 5 == 3) continue;
    if (i > 30 && i.isEven) continue;
    final day = DateTime(_today.year, _today.month, _today.day - i);
    days.add(
      GameDayRecord(
        gameId: GameIds.zip,
        playId: _id(day),
        timeSeconds: 40 + (i * 7) % 75,
        usedHints: i % 4 == 0,
        hadMistakes: false,
        flagsKnown: true,
      ),
    );
  }
  for (final d in [3, 4, 9]) {
    days.add(
      GameDayRecord(
        gameId: GameIds.pathWords,
        playId: _id(DateTime(2026, 9, d)),
        timeSeconds: 95 + d * 4,
        usedHints: false,
        hadMistakes: false,
        flagsKnown: true,
      ),
    );
  }
  return GameHistory(
    days: days,
    streaks: const {
      GameIds.zip: GameStreak(
        gameId: GameIds.zip,
        current: 3,
        longest: 9,
        lastClearedDateId: '20261015',
      ),
      GameIds.pathWords: GameStreak(gameId: GameIds.pathWords, longest: 2),
      GameIds.sudoku: GameStreak(gameId: GameIds.sudoku),
    },
    today: _today,
    remoteIncluded: !remoteFailed,
    remoteFailed: remoteFailed,
  );
}

void main() {
  late _MockLoadHistory load;

  setUp(() {
    load = _MockLoadHistory();
    when(
      () => load(refreshRemote: any(named: 'refreshRemote')),
    ).thenAnswer((_) async => sampleHistory());
  });

  Future<void> pumpStats(WidgetTester tester) async {
    await tester.pumpWidget(
      RepositoryProvider<LoadGameHistory>.value(
        value: load,
        child: MaterialApp(theme: buildAppTheme(), home: const StatsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  void useSmallPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('a tab per game with its numbers', (tester) async {
    await pumpStats(tester);

    expect(find.widgetWithText(Tab, AppStrings.zipTitle), findsOneWidget);
    expect(find.widgetWithText(Tab, AppStrings.pathWordsTitle), findsOneWidget);
    expect(find.widgetWithText(Tab, AppStrings.sudokuTitle), findsOneWidget);
    expect(find.bySemanticsLabel('${AppStrings.statsClears}: 29'), findsOne);
    expect(
      find.bySemanticsLabel('${AppStrings.statsCurrentStreak}: 3'),
      findsOne,
    );
    expect(find.byType(TimeHistogramChart), findsOneWidget);
    verify(() => load(refreshRemote: true)).called(1);

    await tester.tap(find.widgetWithText(Tab, AppStrings.pathWordsTitle));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('${AppStrings.statsClears}: 3'), findsOne);
    expect(
      find.bySemanticsLabel('${AppStrings.statsHintFree}: 100%'),
      findsOne,
    );
  });

  testWidgets('every chart has an empty state', (tester) async {
    await pumpStats(tester);
    await tester.tap(find.widgetWithText(Tab, AppStrings.sudokuTitle));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('${AppStrings.statsClears}: 0'), findsOne);
    expect(
      find.bySemanticsLabel(
        '${AppStrings.statsBestTime}: ${AppStrings.statsNoValue}',
      ),
      findsOne,
    );
    expect(find.text(AppStrings.statsTimesEmpty), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(AppStrings.statsTrendEmpty),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text(AppStrings.statsCalendarEmpty), findsOneWidget);
    expect(find.text(AppStrings.statsTrendEmpty), findsOneWidget);
    expect(find.byType(TimeHistogramChart), findsNothing);
    expect(find.byType(BestTrendChart), findsNothing);
  });

  testWidgets('Path Words has no recent clears, so no trend', (tester) async {
    await pumpStats(tester);
    await tester.tap(find.widgetWithText(Tab, AppStrings.pathWordsTitle));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(AppStrings.statsTrendEmpty),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text(AppStrings.statsTrendEmpty), findsOneWidget);
  });

  testWidgets('the calendar pages back a month', (tester) async {
    await pumpStats(tester);
    await tester.scrollUntilVisible(
      find.text('October 2026'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(AppStrings.statsCalendarCleared(12)), findsOneWidget);

    await tester.tap(find.byTooltip(AppStrings.statsCalendarPrevious));
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);
    await tester.tap(find.byTooltip(AppStrings.statsCalendarPrevious));
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget, reason: 'first month');

    await tester.tap(find.byTooltip(AppStrings.statsCalendarNext));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
  });

  testWidgets('a note when only this phone’s clears are counted', (
    tester,
  ) async {
    when(
      () => load(refreshRemote: any(named: 'refreshRemote')),
    ).thenAnswer((_) async => sampleHistory(remoteFailed: true));
    await pumpStats(tester);
    expect(find.text(AppStrings.statsLocalOnly), findsOneWidget);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    when(
      () => load(refreshRemote: any(named: 'refreshRemote')),
    ).thenAnswer((_) async => throw const Failure('boom'));
    await pumpStats(tester);
    expect(find.text(AppStrings.statsFailed), findsOneWidget);

    when(
      () => load(refreshRemote: any(named: 'refreshRemote')),
    ).thenAnswer((_) async => sampleHistory());
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    expect(find.byType(TimeHistogramChart), findsOneWidget);
  });

  testWidgets('fits a 360×640 phone without overflow on every tab', (
    tester,
  ) async {
    useSmallPhone(tester);
    await pumpStats(tester);

    for (final tab in [
      AppStrings.zipTitle,
      AppStrings.pathWordsTitle,
      AppStrings.sudokuTitle,
    ]) {
      await tester.tap(find.widgetWithText(Tab, tab));
      await tester.pumpAndSettle();
      final list = find.byType(Scrollable).last;
      for (var i = 0; i < 6; i++) {
        await tester.drag(list, const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: tab);
    }
  });
}
