import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../domain/entities/app_update_decision.dart';
import '../../../domain/entities/zip_level.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/play_period.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/repositories/app_update_repository.dart';
import '../../../domain/repositories/update_banner_snooze_repository.dart';
import '../../../domain/repositories/zip_level_repository.dart';
import '../../../domain/usecases/check_app_update.dart';
import '../../../domain/usecases/get_best_daily_time_seconds.dart';
import '../../../domain/usecases/get_best_points.dart';
import '../../../domain/usecases/get_best_time_seconds.dart';
import '../../../domain/usecases/get_streak.dart';
import '../../../domain/usecases/prefetch_tomorrow_puzzles.dart';
import '../../../domain/usecases/schedule_engagement_notifications.dart';
import '../../../core/strings/app_strings.dart';
import '../../zip/logic/daily_puzzle_generator.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({
    required this.getBestPoints,
    required this.getBestTimeSeconds,
    required this.getBestDailyTimeSeconds,
    required this.getStreak,
    required this.analytics,
    required this.checkAppUpdate,
    required this.appUpdateRepository,
    this.scheduleEngagementNotifications,
    required this.zipLevelRepository,
    this.updateBannerSnooze,
    this.prefetchTomorrowPuzzles,
    DateTime? now,
    DateTime Function()? clock,
    this.playPeriod = PlayPeriod.daily,
    Timer Function(Duration wait, void Function() callback)? createTimer,
  }) : _now = now,
       _clockFn = clock,
       _createTimer = createTimer ?? Timer.new,
       super(
         HomeState.initial(
           clock?.call() ?? now ?? DateTime.now(),
           period: playPeriod,
         ),
       );

  /// How long after a new period starts Home reloads, so the new day id is
  /// already in effect.
  static const rolloverSlack = Duration(seconds: 1);

  final GetBestPoints getBestPoints;
  final GetBestTimeSeconds getBestTimeSeconds;
  final GetBestDailyTimeSeconds getBestDailyTimeSeconds;
  final GetStreak getStreak;
  final AnalyticsRepository analytics;
  final CheckAppUpdate checkAppUpdate;
  final AppUpdateRepository appUpdateRepository;
  final ScheduleEngagementNotifications? scheduleEngagementNotifications;
  final ZipLevelRepository zipLevelRepository;

  /// A closed soft banner isn't shown, so it isn't logged as shown.
  final UpdateBannerSnoozeRepository? updateBannerSnooze;

  /// Warms the cache with tomorrow's dailies once they are live.
  final PrefetchTomorrowPuzzles? prefetchTomorrowPuzzles;
  final DateTime? _now;
  final DateTime Function()? _clockFn;
  final Duration playPeriod;
  final Timer Function(Duration wait, void Function() callback) _createTimer;
  Timer? _rolloverTimer;
  var _loadGeneration = 0;
  var _softBannerVisible = false;

  DateTime get _clock => _clockFn?.call() ?? _now ?? DateTime.now();

  /// Reloads when the period after [loadedAt]'s unlocks, in case Home stays
  /// open across midnight. A load that ran past that moment reloads at once.
  /// Coming back to the app reloads too, which covers a timer that fires
  /// late after the phone slept.
  void _scheduleRollover(DateTime loadedAt) {
    _rolloverTimer?.cancel();
    if (isClosed) return;
    final wait =
        PlayPeriod.nextStart(loadedAt, playPeriod).difference(_clock) +
        rolloverSlack;
    _rolloverTimer = _createTimer(wait.isNegative ? Duration.zero : wait, () {
      if (!isClosed) unawaited(load());
    });
  }

  Future<void> load() async {
    // Home reloads often; only the latest load may show its results.
    final generation = ++_loadGeneration;
    final now = _clock;
    final expectedDateId = DailyPuzzleGenerator.dateId(now, period: playPeriod);
    late final ZipLevel level;
    try {
      level = await zipLevelRepository.fetchDailyLevel(now, period: playPeriod);
    } catch (_) {
      // Home still shows streak/score tiles using the expected day id; games
      // themselves refuse to start without a backend puzzle.
      level = ZipLevel(
        id: expectedDateId,
        size: 1,
        numbers: const {},
        walls: const [],
      );
    }
    final zipKey = 'zip_${level.id}';
    final pathWordsKey = 'path_words_${PlayPeriod.id(now, playPeriod)}';
    final sudokuKey = 'sudoku_${PlayPeriod.id(now, playPeriod)}';
    final zipStreak = await getStreak(gameId: GameIds.zip, now: now);
    final pathWordsStreak = await getStreak(
      gameId: GameIds.pathWords,
      now: now,
    );
    final sudokuStreak = await getStreak(gameId: GameIds.sudoku, now: now);
    final zipPts = getBestPoints(zipKey);
    final zipTime = getBestTimeSeconds(zipKey);
    final pathPts = getBestPoints(pathWordsKey);
    final pathTime = getBestTimeSeconds(pathWordsKey);
    final sudokuPts = getBestPoints(sudokuKey);
    final sudokuTime = getBestTimeSeconds(sudokuKey);
    final zipLifetimeBest = getBestDailyTimeSeconds(GameIds.zip);
    final pathWordsLifetimeBest = getBestDailyTimeSeconds(GameIds.pathWords);
    final sudokuLifetimeBest = getBestDailyTimeSeconds(GameIds.sudoku);
    final decision = await checkAppUpdate();
    if (isClosed || generation != _loadGeneration) return;
    _logSoftUpdateShown(decision.status);
    emit(
      state.copyWith(
        dailyLevel: level,
        dateId: level.id,
        loadedAt: now,
        bestPoints: zipPts,
        bestTimeSeconds: zipTime,
        lifetimeBestSeconds: zipLifetimeBest,
        currentStreak: zipStreak.current,
        longestStreak: zipStreak.longest,
        isOnFreeze: zipStreak.isOnFreeze,
        freezeAvailable: zipStreak.freezeAvailable,
        pathWordsBestPoints: pathPts,
        pathWordsBestTimeSeconds: pathTime,
        pathWordsLifetimeBestSeconds: pathWordsLifetimeBest,
        pathWordsCurrentStreak: pathWordsStreak.current,
        pathWordsLongestStreak: pathWordsStreak.longest,
        pathWordsIsOnFreeze: pathWordsStreak.isOnFreeze,
        pathWordsFreezeAvailable: pathWordsStreak.freezeAvailable,
        sudokuBestPoints: sudokuPts,
        sudokuBestTimeSeconds: sudokuTime,
        sudokuLifetimeBestSeconds: sudokuLifetimeBest,
        sudokuCurrentStreak: sudokuStreak.current,
        sudokuLongestStreak: sudokuStreak.longest,
        sudokuIsOnFreeze: sudokuStreak.isOnFreeze,
        sudokuFreezeAvailable: sudokuStreak.freezeAvailable,
        updateStatus: decision.status,
        updateStoreUrl: decision.storeUrl,
        updateCurrentLabel: decision.currentLabel,
        updateRequiredLabel: decision.requiredLabel,
      ),
    );
    _scheduleRollover(now);
    unawaited(prefetchTomorrowPuzzles?.call(now));

    unawaited(
      scheduleEngagementNotifications?.call(
        zipClearedToday: zipPts > 0 || zipTime != null,
        pathWordsClearedToday: pathPts > 0 || pathTime != null,
        sudokuClearedToday: sudokuPts > 0 || sudokuTime != null,
        dailyReadyTitle: AppStrings.notifDailyReadyTitle,
        dailyReadyBody: AppStrings.notifDailyReadyBody,
        streakAtRiskTitle: AppStrings.notifStreakAtRiskTitle,
        streakAtRiskBody: AppStrings.notifStreakAtRiskBody,
      ),
    );
  }

  /// Home reloads on every visit; count the banner once per appearance.
  void _logSoftUpdateShown(AppUpdateStatus next) {
    final snoozedUntil = updateBannerSnooze?.snoozedUntil();
    final snoozed = snoozedUntil != null && _clock.isBefore(snoozedUntil);
    // A closed banner isn't shown; one back from its snooze appears again.
    final visible = next == AppUpdateStatus.soft && !snoozed;
    if (visible && !_softBannerVisible) {
      unawaited(analytics.logUpdatePromptShown(forced: false));
    }
    _softBannerVisible = visible;
  }

  Future<void> recheckUpdate() async {
    final decision = await checkAppUpdate();
    if (isClosed) return;
    _logSoftUpdateShown(decision.status);
    emit(
      state.copyWith(
        updateStatus: decision.status,
        updateStoreUrl: decision.storeUrl,
        updateCurrentLabel: decision.currentLabel,
        updateRequiredLabel: decision.requiredLabel,
      ),
    );
  }

  Future<void> openStore() async {
    final url = state.updateStoreUrl;
    if (url.isEmpty) return;
    unawaited(analytics.logUpdatePromptAccepted(forced: false));
    await appUpdateRepository.openStore(url);
  }

  Future<void> openGame(String gameId) {
    return analytics.logHomeGameOpened(gameId: gameId);
  }

  @override
  Future<void> close() {
    _rolloverTimer?.cancel();
    return super.close();
  }
}
