import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/clear_meta.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
import 'package:winklo/domain/usecases/get_clear_meta.dart';
import 'package:winklo/domain/usecases/watch_leaderboard.dart';
import 'package:winklo/features/results/cubit/cleared_summary_cubit.dart';
import 'package:winklo/features/results/cubit/cleared_summary_state.dart';

class _MockGetBestTimeSeconds extends Mock implements GetBestTimeSeconds {}

class _MockGetClearMeta extends Mock implements GetClearMeta {}

class _MockWatchLeaderboard extends Mock implements WatchLeaderboard {}

class _MockAuthRepository extends Mock implements AuthRepository {}

LeaderboardEntry _entry(String uid, int rank) => LeaderboardEntry(
  uid: uid,
  displayName: uid,
  timeSeconds: 60 + rank,
  updatedAt: DateTime(2026, 10, 14),
  rank: rank,
);

void main() {
  const modeKey = 'zip_daily_20261014';
  final day = DateTime(2026, 10, 14);
  late _MockGetBestTimeSeconds bestTime;
  late _MockGetClearMeta clearMeta;
  late _MockWatchLeaderboard watch;
  late _MockAuthRepository auth;
  late StreamController<List<LeaderboardEntry>> board;

  setUpAll(() => registerFallbackValue(LeaderboardPeriod.daily));

  setUp(() {
    bestTime = _MockGetBestTimeSeconds();
    clearMeta = _MockGetClearMeta();
    watch = _MockWatchLeaderboard();
    auth = _MockAuthRepository();
    board = StreamController<List<LeaderboardEntry>>();
    when(() => bestTime(modeKey)).thenReturn(72);
    when(
      () => clearMeta(modeKey),
    ).thenReturn(const ClearMeta(usedHints: false, hadMistakes: true));
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
  });

  // Not awaited: a board nobody listened to never finishes closing.
  tearDown(() => unawaited(board.close()));

  ClearedSummaryCubit build() => ClearedSummaryCubit(
    gameId: GameIds.zip,
    modeKey: modeKey,
    day: day,
    getBestTimeSeconds: bestTime,
    getClearMeta: clearMeta,
    watchLeaderboard: watch,
    authRepository: auth,
  );

  test("starts with the run's time and flags from this phone", () {
    final cubit = build();
    expect(
      cubit.state,
      const ClearedSummaryState(
        timeSeconds: 72,
        usedHints: false,
        hadMistakes: true,
      ),
    );
    unawaited(cubit.close());
  });

  blocTest<ClearedSummaryCubit, ClearedSummaryState>(
    "reads the player's rank from that day's board",
    build: build,
    act: (_) async {
      board.add([_entry('a', 1), _entry('me', 4)]);
      await Future<void>.delayed(Duration.zero);
      board.add([_entry('me', 3)]);
    },
    expect: () => [
      const ClearedSummaryState(
        timeSeconds: 72,
        usedHints: false,
        hadMistakes: true,
        rank: 4,
      ),
      const ClearedSummaryState(
        timeSeconds: 72,
        usedHints: false,
        hadMistakes: true,
        rank: 3,
      ),
    ],
    verify: (_) {
      verify(
        () => watch(
          gameId: GameIds.zip,
          period: LeaderboardPeriod.daily,
          dayId: '2026-10-14',
        ),
      ).called(1);
    },
  );

  blocTest<ClearedSummaryCubit, ClearedSummaryState>(
    'no rank when the player is not on the board',
    build: build,
    act: (_) => board.add([_entry('a', 1)]),
    expect: () => <ClearedSummaryState>[],
  );

  blocTest<ClearedSummaryCubit, ClearedSummaryState>(
    'a board that fails to load just leaves the rank out',
    build: build,
    act: (_) => board.addError(Exception('offline')),
    expect: () => <ClearedSummaryState>[],
  );

  test('signed out, it never watches the board', () async {
    when(() => auth.currentUser).thenReturn(null);
    final cubit = build();
    await cubit.close();
    verifyNever(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    );
  });
}
