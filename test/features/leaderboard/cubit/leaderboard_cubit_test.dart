import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/watch_leaderboard.dart';
import 'package:winklo/features/leaderboard/cubit/leaderboard_cubit.dart';
import 'package:winklo/features/leaderboard/cubit/leaderboard_state.dart';

class _MockWatchLeaderboard extends Mock implements WatchLeaderboard {}

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  final entry = LeaderboardEntry(
    uid: 'u1',
    displayName: 'Ada',
    timeSeconds: 12,
    updatedAt: DateTime.utc(2026, 9, 24),
    rank: 1,
  );

  late _MockWatchLeaderboard watch;
  late _MockAuthRepository auth;
  late StreamController<List<LeaderboardEntry>> boardController;
  late StreamController<AppUser?> authController;

  setUpAll(() {
    registerFallbackValue(LeaderboardPeriod.daily);
  });

  setUp(() {
    watch = _MockWatchLeaderboard();
    auth = _MockAuthRepository();
    boardController = StreamController<List<LeaderboardEntry>>.broadcast();
    authController = StreamController<AppUser?>.broadcast();
    when(() => auth.currentUser).thenReturn(null);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => authController.stream);
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => boardController.stream);
  });

  tearDown(() async {
    await boardController.close();
    await authController.close();
  });

  LeaderboardCubit buildCubit() =>
      LeaderboardCubit(watchLeaderboard: watch, authRepository: auth);

  blocTest<LeaderboardCubit, LeaderboardState>(
    'emits ready entries from watch stream',
    build: buildCubit,
    act: (cubit) => boardController.add([entry]),
    expect: () => [
      LeaderboardState(status: LeaderboardStatus.ready, entries: [entry]),
    ],
  );

  blocTest<LeaderboardCubit, LeaderboardState>(
    'selectPeriod resubscribes and can emit failure',
    build: buildCubit,
    act: (cubit) {
      cubit.selectPeriod(LeaderboardPeriod.allTime);
      boardController.addError(const Failure('offline'));
    },
    expect: () => [
      const LeaderboardState(
        period: LeaderboardPeriod.allTime,
        status: LeaderboardStatus.loading,
      ),
      const LeaderboardState(
        period: LeaderboardPeriod.allTime,
        status: LeaderboardStatus.failure,
        error: 'offline',
      ),
    ],
  );

  blocTest<LeaderboardCubit, LeaderboardState>(
    'selectGame switches to path words',
    build: buildCubit,
    act: (cubit) => cubit.selectGame(GameIds.pathWords),
    expect: () => [
      const LeaderboardState(
        gameId: GameIds.pathWords,
        status: LeaderboardStatus.loading,
      ),
    ],
    verify: (_) {
      verify(
        () => watch(
          gameId: GameIds.pathWords,
          period: LeaderboardPeriod.daily,
          dayId: any(named: 'dayId'),
        ),
      ).called(greaterThan(0));
    },
  );
}
