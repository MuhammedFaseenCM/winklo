import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/clear_meta.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/entities/path_words_puzzle.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/tutorial_repository.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
import 'package:winklo/domain/usecases/get_clear_meta.dart';
import 'package:winklo/domain/usecases/watch_leaderboard.dart';
import 'package:winklo/features/path_words/bloc/path_words_bloc.dart';
import 'package:winklo/features/path_words/bloc/path_words_event.dart';
import 'package:winklo/features/path_words/bloc/path_words_state.dart';
import 'package:winklo/features/path_words/view/path_words_screen.dart';
import 'package:winklo/features/path_words/view/widgets/path_words_definition_sheet.dart';

class _MockPathWordsBloc extends MockBloc<PathWordsEvent, PathWordsState>
    implements PathWordsBloc {}

class _MockTutorialRepository extends Mock implements TutorialRepository {}

class _MockGetBestTimeSeconds extends Mock implements GetBestTimeSeconds {}

class _MockGetClearMeta extends Mock implements GetClearMeta {}

class _MockWatchLeaderboard extends Mock implements WatchLeaderboard {}

class _MockAuthRepository extends Mock implements AuthRepository {}

final _day = DateTime(2026, 9, 17);

final _puzzle = PathWordsPuzzle(
  id: 'daily_20260917',
  day: _day,
  size: 2,
  letters: const ['a', 'b', 'c', 'd'],
  targets: const [
    PathWordsTarget(
      id: 't0',
      word: 'ab',
      start: Cell(0, 0),
      path: [Cell(0, 0), Cell(0, 1)],
      colorIndex: 0,
    ),
    PathWordsTarget(
      id: 't1',
      word: 'cd',
      start: Cell(1, 0),
      path: [Cell(1, 0), Cell(1, 1)],
      colorIndex: 1,
    ),
  ],
  theme: 'Alphabet',
  definitions: const {'ab': 'The first two letters, in order'},
);

Future<void> _pump(WidgetTester tester, PathWordsState state) async {
  final bloc = _MockPathWordsBloc();
  when(() => bloc.state).thenReturn(state);
  when(() => bloc.clearModeKey).thenReturn('path_words_20260917');
  whenListen(bloc, const Stream<PathWordsState>.empty(), initialState: state);
  final tutorials = _MockTutorialRepository();
  when(
    () => tutorials.hasSeen(GameIds.pathWords),
  ).thenAnswer((_) async => true);
  when(() => tutorials.markSeen(GameIds.pathWords)).thenAnswer((_) async {});
  final bestTime = _MockGetBestTimeSeconds();
  when(() => bestTime(any())).thenReturn(72);
  final clearMeta = _MockGetClearMeta();
  when(
    () => clearMeta(any()),
  ).thenReturn(const ClearMeta(usedHints: false, hadMistakes: false));
  final board = StreamController<List<LeaderboardEntry>>.broadcast();
  addTearDown(board.close);
  final watch = _MockWatchLeaderboard();
  when(
    () => watch(
      gameId: any(named: 'gameId'),
      period: any(named: 'period'),
      dayId: any(named: 'dayId'),
    ),
  ).thenAnswer((_) => board.stream);
  final auth = _MockAuthRepository();
  when(
    () => auth.currentUser,
  ).thenReturn(const AppUser(uid: 'me', displayName: 'Me'));

  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TutorialRepository>.value(value: tutorials),
        RepositoryProvider<GetBestTimeSeconds>.value(value: bestTime),
        RepositoryProvider<GetClearMeta>.value(value: clearMeta),
        RepositoryProvider<WatchLeaderboard>.value(value: watch),
        RepositoryProvider<AuthRepository>.value(value: auth),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: PathWordsScreen(bloc: bloc, autoStart: false),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(() => registerFallbackValue(LeaderboardPeriod.daily));

  testWidgets('review mode shows the theme and opens a definition', (
    tester,
  ) async {
    await _pump(
      tester,
      PathWordsState(
        day: _day,
        puzzle: _puzzle,
        status: PathWordsStatus.locked,
        finished: true,
        completedTargetIds: const {'t0', 't1'},
      ),
    );
    expect(find.text('Today: Alphabet'), findsOneWidget);
    expect(find.byKey(const Key('pathWordsMeaning_t0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('pathWordsWord_t0')));
    // The countdown under the board ticks forever, so no pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PathWordsDefinitionSheet), findsOneWidget);
    expect(find.text('The first two letters, in order'), findsOneWidget);
  });

  testWidgets('while playing there is no theme and no definitions', (
    tester,
  ) async {
    await _pump(
      tester,
      PathWordsState(
        day: _day,
        puzzle: _puzzle,
        status: PathWordsStatus.playing,
        completedTargetIds: const {'t0'},
        resumedAt: _day,
      ),
    );
    expect(find.textContaining('Today:'), findsNothing);
    expect(find.byKey(const Key('pathWordsMeaning_t0')), findsNothing);
    await tester.tap(find.byKey(const Key('pathWordsWord_t0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PathWordsDefinitionSheet), findsNothing);
  });
}
