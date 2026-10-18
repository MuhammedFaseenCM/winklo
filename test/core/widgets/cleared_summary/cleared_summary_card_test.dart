import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/clear_meta.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
import 'package:winklo/domain/usecases/get_clear_meta.dart';
import 'package:winklo/domain/usecases/watch_leaderboard.dart';
import 'package:winklo/core/widgets/cleared_summary/cleared_summary_card.dart';

class _MockGetBestTimeSeconds extends Mock implements GetBestTimeSeconds {}

class _MockGetClearMeta extends Mock implements GetClearMeta {}

class _MockWatchLeaderboard extends Mock implements WatchLeaderboard {}

class _MockAuthRepository extends Mock implements AuthRepository {}

/// The card keeps each chunk, and the dot after it, on one line with
/// non-breaking spaces.
String shown(String summary) => summary
    .split(' · ')
    .map((chunk) => chunk.replaceAll(' ', '\u00A0'))
    .join('\u00A0· ');

void main() {
  setUpAll(() => registerFallbackValue(LeaderboardPeriod.daily));

  testWidgets('sums up the clear and opens the full board', (tester) async {
    final bestTime = _MockGetBestTimeSeconds();
    final clearMeta = _MockGetClearMeta();
    final watch = _MockWatchLeaderboard();
    final auth = _MockAuthRepository();
    final board = StreamController<List<LeaderboardEntry>>();
    addTearDown(board.close);
    when(() => bestTime(any())).thenReturn(72);
    when(
      () => clearMeta(any()),
    ).thenReturn(const ClearMeta(usedHints: false, hadMistakes: false));
    when(
      () => auth.currentUser,
    ).thenReturn(const AppUser(uid: 'me', displayName: 'Me'));
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => board.stream);

    final router = GoRouter(
      initialLocation: '/zip',
      routes: [
        GoRoute(
          path: '/zip',
          builder: (_, _) => Scaffold(
            body: ClearedSummaryCard(
              gameId: GameIds.zip,
              modeKey: 'zip_daily_20261014',
              day: DateTime.now(),
            ),
          ),
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (_, state) =>
              Text('board:${state.uri.queryParameters['game']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<GetBestTimeSeconds>.value(value: bestTime),
          RepositoryProvider<GetClearMeta>.value(value: clearMeta),
          RepositoryProvider<WatchLeaderboard>.value(value: watch),
          RepositoryProvider<AuthRepository>.value(value: auth),
        ],
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    await tester.pump();
    expect(find.text(shown('Cleared in 1:12 · Hint-free')), findsOneWidget);
    expect(find.textContaining('New puzzle in'), findsOneWidget);

    board.add([
      LeaderboardEntry(
        uid: 'me',
        displayName: 'Me',
        timeSeconds: 72,
        updatedAt: DateTime(2026, 10, 14),
        rank: 4,
      ),
    ]);
    await tester.pump();
    await tester.pump();
    expect(
      find.text(shown('Cleared in 1:12 · #4 today · Hint-free')),
      findsOneWidget,
    );

    await tester.tap(find.text(AppStrings.resultsFullBoard));
    await tester.pumpAndSettle();
    expect(find.text('board:zip'), findsOneWidget);
  });
}
