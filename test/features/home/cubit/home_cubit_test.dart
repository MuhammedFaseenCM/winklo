import 'package:bloc_test/bloc_test.dart';
import 'package:winklo/domain/entities/app_update_decision.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/app_update_repository.dart';
import 'package:winklo/domain/repositories/zip_level_repository.dart';
import 'package:winklo/domain/usecases/check_app_update.dart';
import 'package:winklo/domain/usecases/get_best_points.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
import 'package:winklo/domain/usecases/get_streak.dart';
import 'package:winklo/features/home/cubit/home_cubit.dart';
import 'package:winklo/features/home/cubit/home_state.dart';
import 'package:winklo/features/zip/logic/daily_puzzle_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_repository.dart';

class _MockGetBestPoints extends Mock implements GetBestPoints {}

class _MockGetBestTimeSeconds extends Mock implements GetBestTimeSeconds {}

class _MockGetStreak extends Mock implements GetStreak {}

class _MockCheckAppUpdate extends Mock implements CheckAppUpdate {}

class _MockAppUpdateRepository extends Mock implements AppUpdateRepository {}

class _MockZipLevelRepository extends Mock implements ZipLevelRepository {}

void main() {
  late _MockGetBestPoints pts;
  late _MockGetBestTimeSeconds time;
  late _MockGetStreak getStreak;
  late MockAnalyticsRepository analytics;
  late _MockCheckAppUpdate checkAppUpdate;
  late _MockAppUpdateRepository appUpdateRepository;
  late _MockZipLevelRepository zipLevels;

  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(DateTime(2026, 9, 13));
  });

  setUp(() {
    pts = _MockGetBestPoints();
    time = _MockGetBestTimeSeconds();
    getStreak = _MockGetStreak();
    analytics = MockAnalyticsRepository();
    checkAppUpdate = _MockCheckAppUpdate();
    appUpdateRepository = _MockAppUpdateRepository();
    zipLevels = _MockZipLevelRepository();
    stubAnalytics(analytics);
    when(
      () => checkAppUpdate(),
    ).thenAnswer((_) async => AppUpdateDecision.none);
    when(
      () => appUpdateRepository.openStore(any()),
    ).thenAnswer((_) async => true);
    when(
      () => zipLevels.fetchDailyLevel(any(), period: any(named: 'period')),
    ).thenAnswer((inv) async {
      final date = inv.positionalArguments[0] as DateTime;
      final period =
          inv.namedArguments[#period] as Duration? ?? PlayPeriod.daily;
      return DailyPuzzleGenerator.forDate(date, period: period);
    });
  });

  HomeCubit buildCubit({
    DateTime? now,
    Duration playPeriod = PlayPeriod.daily,
  }) {
    return HomeCubit(
      getBestPoints: pts,
      getBestTimeSeconds: time,
      getStreak: getStreak,
      analytics: analytics,
      checkAppUpdate: checkAppUpdate,
      appUpdateRepository: appUpdateRepository,
      zipLevelRepository: zipLevels,
      now: now ?? DateTime.utc(2026, 9, 13),
      playPeriod: playPeriod,
    );
  }

  void stubIdleScores() {
    when(() => pts(any())).thenReturn(0);
    when(() => time(any())).thenReturn(null);
    when(
      () => getStreak(
        gameId: any(named: 'gameId'),
        now: any(named: 'now'),
      ),
    ).thenAnswer((_) async => const GameStreak(gameId: GameIds.zip));
  }

  blocTest<HomeCubit, HomeState>(
    'loads bests and streak for daily zip',
    build: () {
      when(() => pts(any())).thenReturn(42);
      when(() => time(any())).thenReturn(11);
      when(
        () => getStreak(
          gameId: GameIds.zip,
          now: any(named: 'now'),
        ),
      ).thenAnswer(
        (_) async => const GameStreak(
          gameId: GameIds.zip,
          current: 4,
          longest: 7,
          lastClearedDateId: '20260913',
        ),
      );
      when(
        () => getStreak(
          gameId: GameIds.pathWords,
          now: any(named: 'now'),
        ),
      ).thenAnswer((_) async => const GameStreak(gameId: GameIds.pathWords));
      when(
        () => getStreak(
          gameId: GameIds.sudoku,
          now: any(named: 'now'),
        ),
      ).thenAnswer((_) async => const GameStreak(gameId: GameIds.sudoku));

      return buildCubit();
    },
    act: (c) => c.load(),
    expect: () => [
      isA<HomeState>()
          .having((s) => s.bestPoints, 'bestPoints', 42)
          .having((s) => s.bestTimeSeconds, 'bestTimeSeconds', 11)
          .having((s) => s.currentStreak, 'currentStreak', 4)
          .having((s) => s.longestStreak, 'longestStreak', 7)
          .having((s) => s.updateStatus, 'updateStatus', AppUpdateStatus.none),
    ],
    verify: (_) {
      verify(() => pts('zip_daily_20260913')).called(1);
      verify(() => time('zip_daily_20260913')).called(1);
      verify(
        () => getStreak(
          gameId: GameIds.zip,
          now: any(named: 'now'),
        ),
      ).called(1);
    },
  );

  blocTest<HomeCubit, HomeState>(
    'loads bests and streak for daily path words',
    build: () {
      when(() => pts(any())).thenReturn(0);
      when(() => time(any())).thenReturn(null);
      when(() => pts('path_words_20260913')).thenReturn(18);
      when(() => time('path_words_20260913')).thenReturn(29);
      when(
        () => getStreak(
          gameId: GameIds.zip,
          now: any(named: 'now'),
        ),
      ).thenAnswer((_) async => const GameStreak(gameId: GameIds.zip));
      when(
        () => getStreak(
          gameId: GameIds.pathWords,
          now: any(named: 'now'),
        ),
      ).thenAnswer(
        (_) async => const GameStreak(
          gameId: GameIds.pathWords,
          current: 3,
          longest: 5,
          lastClearedDateId: '20260913',
          isOnFreeze: true,
        ),
      );
      when(
        () => getStreak(
          gameId: GameIds.sudoku,
          now: any(named: 'now'),
        ),
      ).thenAnswer((_) async => const GameStreak(gameId: GameIds.sudoku));

      return buildCubit();
    },
    act: (c) => c.load(),
    expect: () => [
      isA<HomeState>()
          .having((s) => s.pathWordsBestPoints, 'pathWordsBestPoints', 18)
          .having(
            (s) => s.pathWordsBestTimeSeconds,
            'pathWordsBestTimeSeconds',
            29,
          )
          .having((s) => s.pathWordsCurrentStreak, 'pathWordsCurrentStreak', 3)
          .having((s) => s.pathWordsLongestStreak, 'pathWordsLongestStreak', 5)
          .having((s) => s.pathWordsIsOnFreeze, 'pathWordsIsOnFreeze', true),
    ],
    verify: (_) {
      verify(() => pts('path_words_20260913')).called(1);
      verify(() => time('path_words_20260913')).called(1);
      verify(
        () => getStreak(
          gameId: GameIds.pathWords,
          now: any(named: 'now'),
        ),
      ).called(1);
    },
  );

  blocTest<HomeCubit, HomeState>(
    'loads bests and streak for daily sudoku',
    build: () {
      when(() => pts(any())).thenReturn(0);
      when(() => time(any())).thenReturn(null);
      when(() => pts('sudoku_20260913')).thenReturn(880);
      when(() => time('sudoku_20260913')).thenReturn(40);
      when(
        () => getStreak(
          gameId: GameIds.zip,
          now: any(named: 'now'),
        ),
      ).thenAnswer((_) async => const GameStreak(gameId: GameIds.zip));
      when(
        () => getStreak(
          gameId: GameIds.pathWords,
          now: any(named: 'now'),
        ),
      ).thenAnswer((_) async => const GameStreak(gameId: GameIds.pathWords));
      when(
        () => getStreak(
          gameId: GameIds.sudoku,
          now: any(named: 'now'),
        ),
      ).thenAnswer(
        (_) async => const GameStreak(
          gameId: GameIds.sudoku,
          current: 2,
          longest: 4,
          lastClearedDateId: '20260913',
        ),
      );

      return buildCubit();
    },
    act: (c) => c.load(),
    expect: () => [
      isA<HomeState>()
          .having((s) => s.sudokuBestPoints, 'sudokuBestPoints', 880)
          .having((s) => s.sudokuBestTimeSeconds, 'sudokuBestTimeSeconds', 40)
          .having((s) => s.sudokuCurrentStreak, 'sudokuCurrentStreak', 2)
          .having((s) => s.sudokuLongestStreak, 'sudokuLongestStreak', 4),
    ],
    verify: (_) {
      verify(() => pts('sudoku_20260913')).called(1);
      verify(() => time('sudoku_20260913')).called(1);
      verify(
        () => getStreak(
          gameId: GameIds.sudoku,
          now: any(named: 'now'),
        ),
      ).called(1);
    },
  );

  blocTest<HomeCubit, HomeState>(
    'minute play period reads this minute\'s scores',
    build: () {
      when(() => pts(any())).thenReturn(0);
      when(() => time(any())).thenReturn(null);
      when(() => pts('zip_daily_202609201431')).thenReturn(500);
      when(() => time('path_words_202609201431')).thenReturn(20);
      when(
        () => getStreak(
          gameId: any(named: 'gameId'),
          now: any(named: 'now'),
        ),
      ).thenAnswer((_) async => const GameStreak(gameId: GameIds.zip));

      return buildCubit(
        now: DateTime(2026, 9, 20, 14, 31, 50),
        playPeriod: PlayPeriod.minute,
      );
    },
    act: (c) => c.load(),
    expect: () => [
      isA<HomeState>()
          .having((s) => s.dateId, 'dateId', 'daily_202609201431')
          .having((s) => s.bestPoints, 'bestPoints', 500)
          .having((s) => s.pathWordsBestTimeSeconds, 'pathWordsTime', 20),
    ],
  );

  blocTest<HomeCubit, HomeState>(
    'openGame logs home_game_opened',
    build: () {
      stubIdleScores();
      return buildCubit();
    },
    act: (c) => c.openGame(GameIds.zip),
    expect: () => <HomeState>[],
    verify: (_) {
      verify(() => analytics.logHomeGameOpened(gameId: GameIds.zip)).called(1);
    },
  );

  blocTest<HomeCubit, HomeState>(
    'load applies a soft update decision and labels',
    build: () {
      stubIdleScores();
      when(() => checkAppUpdate()).thenAnswer(
        (_) async => const AppUpdateDecision(
          status: AppUpdateStatus.soft,
          storeUrl:
              'https://play.google.com/store/apps/details?id=com.winklo.faseencm',
          currentLabel: '1.0.0+1',
          requiredLabel: '1.0.0+2',
        ),
      );
      return buildCubit();
    },
    act: (c) => c.load(),
    expect: () => [
      isA<HomeState>()
          .having((s) => s.updateStatus, 'updateStatus', AppUpdateStatus.soft)
          .having((s) => s.updateCurrentLabel, 'updateCurrentLabel', '1.0.0+1')
          .having(
            (s) => s.updateRequiredLabel,
            'updateRequiredLabel',
            '1.0.0+2',
          )
          .having(
            (s) => s.updateStoreUrl,
            'updateStoreUrl',
            'https://play.google.com/store/apps/details?id=com.winklo.faseencm',
          ),
    ],
  );

  blocTest<HomeCubit, HomeState>(
    'load applies a forced update decision',
    build: () {
      stubIdleScores();
      when(() => checkAppUpdate()).thenAnswer(
        (_) async => const AppUpdateDecision(
          status: AppUpdateStatus.forced,
          storeUrl:
              'https://play.google.com/store/apps/details?id=com.winklo.faseencm',
          currentLabel: '1.0.0+10',
          requiredLabel: '2.0.0+0',
        ),
      );
      return buildCubit();
    },
    act: (c) => c.load(),
    expect: () => [
      isA<HomeState>()
          .having((s) => s.updateStatus, 'updateStatus', AppUpdateStatus.forced)
          .having((s) => s.updateCurrentLabel, 'updateCurrentLabel', '1.0.0+10')
          .having(
            (s) => s.updateRequiredLabel,
            'updateRequiredLabel',
            '2.0.0+0',
          ),
    ],
  );
}
