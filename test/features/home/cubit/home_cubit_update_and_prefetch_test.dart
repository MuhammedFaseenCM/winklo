import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/app_update_decision.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/app_update_repository.dart';
import 'package:winklo/domain/repositories/daily_puzzle_prefetch_repository.dart';
import 'package:winklo/domain/repositories/update_banner_snooze_repository.dart';
import 'package:winklo/domain/repositories/zip_level_repository.dart';
import 'package:winklo/domain/usecases/check_app_update.dart';
import 'package:winklo/domain/usecases/get_best_daily_time_seconds.dart';
import 'package:winklo/domain/usecases/get_best_points.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
import 'package:winklo/domain/usecases/get_streak.dart';
import 'package:winklo/domain/usecases/prefetch_tomorrow_puzzles.dart';
import 'package:winklo/features/home/cubit/home_cubit.dart';
import 'package:winklo/features/zip/logic/daily_puzzle_generator.dart';

import '../../../helpers/mock_analytics_repository.dart';

class _MockGetBestPoints extends Mock implements GetBestPoints {}

class _MockGetBestTimeSeconds extends Mock implements GetBestTimeSeconds {}

class _MockGetBestDailyTimeSeconds extends Mock
    implements GetBestDailyTimeSeconds {}

class _MockGetStreak extends Mock implements GetStreak {}

class _MockCheckAppUpdate extends Mock implements CheckAppUpdate {}

class _MockAppUpdateRepository extends Mock implements AppUpdateRepository {}

class _MockZipLevelRepository extends Mock implements ZipLevelRepository {}

class _FixedSnooze implements UpdateBannerSnoozeRepository {
  _FixedSnooze(this.until);
  DateTime? until;

  @override
  DateTime? snoozedUntil() => until;

  @override
  Future<void> snoozeUntil(DateTime until) async {}
}

class _RecordingPrefetch implements DailyPuzzlePrefetchRepository {
  final List<String> days = [];

  @override
  Future<bool> prefetch(String dateId) async {
    days.add(dateId);
    return true;
  }
}

void main() {
  final noonUtc = DateTime.utc(2026, 10, 15, 12);
  const soft = AppUpdateDecision(
    status: AppUpdateStatus.soft,
    storeUrl: 'https://play.google.com/store/apps/details?id=x',
  );

  late MockAnalyticsRepository analytics;
  late _MockCheckAppUpdate checkAppUpdate;
  late _MockGetBestPoints points;
  late _MockGetBestTimeSeconds times;
  late _MockGetBestDailyTimeSeconds lifetimeBest;
  late _MockGetStreak streaks;
  late _MockZipLevelRepository zipLevels;

  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(DateTime(2026, 10, 15));
  });

  setUp(() {
    analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    checkAppUpdate = _MockCheckAppUpdate();
    when(() => checkAppUpdate()).thenAnswer((_) async => soft);
    points = _MockGetBestPoints();
    when(() => points(any())).thenReturn(0);
    times = _MockGetBestTimeSeconds();
    when(() => times(any())).thenReturn(null);
    lifetimeBest = _MockGetBestDailyTimeSeconds();
    when(() => lifetimeBest(any())).thenReturn(null);
    streaks = _MockGetStreak();
    when(
      () => streaks(
        gameId: any(named: 'gameId'),
        now: any(named: 'now'),
      ),
    ).thenAnswer((_) async => const GameStreak(gameId: GameIds.zip));
    zipLevels = _MockZipLevelRepository();
    when(
      () => zipLevels.fetchDailyLevel(any(), period: any(named: 'period')),
    ).thenAnswer(
      (inv) async => DailyPuzzleGenerator.forDate(
        inv.positionalArguments[0] as DateTime,
        period: PlayPeriod.daily,
      ),
    );
  });

  HomeCubit build({
    UpdateBannerSnoozeRepository? snooze,
    PrefetchTomorrowPuzzles? prefetch,
    DateTime? now,
  }) => HomeCubit(
    getBestPoints: points,
    getBestTimeSeconds: times,
    getBestDailyTimeSeconds: lifetimeBest,
    getStreak: streaks,
    analytics: analytics,
    checkAppUpdate: checkAppUpdate,
    appUpdateRepository: _MockAppUpdateRepository(),
    zipLevelRepository: zipLevels,
    updateBannerSnooze: snooze,
    prefetchTomorrowPuzzles: prefetch,
    now: now ?? noonUtc,
    createTimer: (_, _) => Timer(Duration.zero, () {}),
  );

  group('update_prompt_shown and the snooze', () {
    test('a snoozed banner is not logged as shown', () async {
      final cubit = build(
        snooze: _FixedSnooze(noonUtc.add(const Duration(hours: 5))),
      );

      await cubit.load();

      verifyNever(
        () => analytics.logUpdatePromptShown(forced: any(named: 'forced')),
      );
      await cubit.close();
    });

    test('a banner back from a snooze in the same session is logged', () async {
      final snooze = _FixedSnooze(noonUtc.add(const Duration(hours: 5)));
      final cubit = build(snooze: snooze);
      await cubit.load();

      snooze.until = noonUtc.subtract(const Duration(minutes: 1));
      await cubit.load();
      await cubit.load();

      verify(() => analytics.logUpdatePromptShown(forced: false)).called(1);
      await cubit.close();
    });

    test('a snooze that ended is logged as shown again', () async {
      final cubit = build(
        snooze: _FixedSnooze(noonUtc.subtract(const Duration(minutes: 1))),
      );

      await cubit.load();

      verify(() => analytics.logUpdatePromptShown(forced: false)).called(1);
      await cubit.close();
    });
  });

  test('loading Home prefetches tomorrow once it is live', () async {
    final repo = _RecordingPrefetch();
    // 23:00 local: tomorrow went live at 10:00 UTC today, in any time zone
    // short of UTC+13.
    final cubit = build(
      prefetch: PrefetchTomorrowPuzzles(repo),
      now: DateTime(2026, 10, 15, 23),
    );

    await cubit.load();
    await pumpEventQueue();

    expect(repo.days, ['20261016']);
    await cubit.close();
  });
}
