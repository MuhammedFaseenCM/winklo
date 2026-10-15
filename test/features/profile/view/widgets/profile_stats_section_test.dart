import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/lifecycle/progress_change_signal.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/game_day_record.dart';
import 'package:winklo/domain/entities/game_history.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/usecases/load_game_history.dart';
import 'package:winklo/features/achievements/view/achievement_badge_grid.dart';
import 'package:winklo/features/profile/view/widgets/profile_stats_section.dart';

class _MockLoadHistory extends Mock implements LoadGameHistory {}

GameHistory _history(List<GameDayRecord> days) =>
    GameHistory(days: days, streaks: const {}, today: DateTime(2026, 10, 15));

const _zip = GameDayRecord(
  gameId: GameIds.zip,
  playId: '20261015',
  timeSeconds: 80,
  usedHints: true,
  hadMistakes: false,
  flagsKnown: true,
);

void main() {
  late _MockLoadHistory load;

  setUp(() {
    load = _MockLoadHistory();
    when(
      () => load(refreshRemote: any(named: 'refreshRemote')),
    ).thenAnswer((_) async => _history(const [_zip]));
  });

  Future<void> pumpSection(
    WidgetTester tester, {
    bool provideHistory = true,
    ProgressChangeSignal? signal,
  }) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: SingleChildScrollView(child: ProfileStatsSection()),
          ),
        ),
        GoRoute(
          path: '/profile/stats',
          builder: (context, state) => const Text('stats page'),
        ),
      ],
    );
    addTearDown(router.dispose);
    final app = MaterialApp.router(
      theme: buildAppTheme(),
      routerConfig: router,
    );
    await tester.pumpWidget(
      provideHistory
          ? MultiRepositoryProvider(
              providers: [
                RepositoryProvider<LoadGameHistory>.value(value: load),
                if (signal != null)
                  RepositoryProvider<ProgressChangeSignal>.value(value: signal),
              ],
              child: app,
            )
          : app,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the stats row and the badge count', (tester) async {
    await pumpSection(tester);

    expect(find.text(AppStrings.statsProfileRow), findsOneWidget);
    expect(find.text(AppStrings.achievementsTitle), findsOneWidget);
    expect(find.text(AppStrings.achievementsProgress(1, 16)), findsOneWidget);
    expect(find.text('First Zip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the stats row opens /profile/stats', (tester) async {
    await pumpSection(tester);

    await tester.tap(find.text(AppStrings.statsProfileRow));
    await tester.pumpAndSettle();

    expect(find.text('stats page'), findsOneWidget);
  });

  testWidgets('a new clear lights its badge', (tester) async {
    final signal = ProgressChangeSignal();
    addTearDown(signal.dispose);
    await pumpSection(tester, signal: signal);
    expect(find.text('First Sudoku'), findsNothing);

    when(() => load(refreshRemote: any(named: 'refreshRemote'))).thenAnswer(
      (_) async => _history([
        _zip,
        const GameDayRecord(
          gameId: GameIds.sudoku,
          playId: '20261015',
          timeSeconds: 120,
        ),
      ]),
    );
    signal.notify();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('First Sudoku'), findsOneWidget);
    expect(find.text(AppStrings.achievementsProgress(2, 16)), findsOneWidget);
  });

  testWidgets('renders nothing without LoadGameHistory', (tester) async {
    await pumpSection(tester, provideHistory: false);

    expect(find.text(AppStrings.statsProfileRow), findsNothing);
    expect(find.byType(AchievementBadgeGrid), findsNothing);
  });
}
