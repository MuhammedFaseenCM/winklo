import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../domain/game_ids.dart';
import '../../../domain/play_period.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/repositories/app_update_repository.dart';
import '../../../domain/usecases/check_app_update.dart';
import '../../../domain/usecases/get_best_points.dart';
import '../../../domain/usecases/get_best_time_seconds.dart';
import '../../../domain/usecases/get_streak.dart';
import '../../../domain/usecases/schedule_engagement_notifications.dart';
import '../../../core/strings/app_strings.dart';
import '../../zip/logic/daily_puzzle_generator.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({
    required this.getBestPoints,
    required this.getBestTimeSeconds,
    required this.getStreak,
    required this.analytics,
    required this.checkAppUpdate,
    required this.appUpdateRepository,
    this.scheduleEngagementNotifications,
    DateTime? now,
    this.playPeriod = PlayPeriod.daily,
  }) : _now = now,
       super(HomeState.initial(now ?? DateTime.now(), period: playPeriod)) {
    _scheduleRefresh();
  }

  final GetBestPoints getBestPoints;
  final GetBestTimeSeconds getBestTimeSeconds;
  final GetStreak getStreak;
  final AnalyticsRepository analytics;
  final CheckAppUpdate checkAppUpdate;
  final AppUpdateRepository appUpdateRepository;
  final ScheduleEngagementNotifications? scheduleEngagementNotifications;
  final DateTime? _now;
  final Duration playPeriod;
  Timer? _refreshTimer;

  DateTime get _clock => _now ?? DateTime.now();

  void _scheduleRefresh() {
    if (!PlayPeriod.isSubDaily(playPeriod)) return;
    if (_now != null) return;
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final nextId = DailyPuzzleGenerator.dateId(_clock, period: playPeriod);
      if (nextId != state.dateId) {
        load();
      }
    });
  }

  Future<void> load() async {
    final now = _clock;
    final level = DailyPuzzleGenerator.forDate(now, period: playPeriod);
    final zipKey = 'zip_${level.id}';
    final pathWordsKey = 'path_words_${PlayPeriod.id(now, playPeriod)}';
    final zipStreak = await getStreak(gameId: GameIds.zip, now: now);
    final pathWordsStreak = await getStreak(
      gameId: GameIds.pathWords,
      now: now,
    );
    final zipPts = getBestPoints(zipKey);
    final zipTime = getBestTimeSeconds(zipKey);
    final pathPts = getBestPoints(pathWordsKey);
    final pathTime = getBestTimeSeconds(pathWordsKey);
    final decision = await checkAppUpdate();
    if (isClosed) return;
    emit(
      state.copyWith(
        dailyLevel: level,
        dateId: level.id,
        bestPoints: zipPts,
        bestTimeSeconds: zipTime,
        currentStreak: zipStreak.current,
        longestStreak: zipStreak.longest,
        isOnFreeze: zipStreak.isOnFreeze,
        freezeAvailable: zipStreak.freezeAvailable,
        pathWordsBestPoints: pathPts,
        pathWordsBestTimeSeconds: pathTime,
        pathWordsCurrentStreak: pathWordsStreak.current,
        pathWordsLongestStreak: pathWordsStreak.longest,
        pathWordsIsOnFreeze: pathWordsStreak.isOnFreeze,
        pathWordsFreezeAvailable: pathWordsStreak.freezeAvailable,
        updateStatus: decision.status,
        updateStoreUrl: decision.storeUrl,
        updateCurrentLabel: decision.currentLabel,
        updateRequiredLabel: decision.requiredLabel,
      ),
    );

    unawaited(
      scheduleEngagementNotifications?.call(
        zipClearedToday: zipPts > 0 || zipTime != null,
        pathWordsClearedToday: pathPts > 0 || pathTime != null,
        dailyReadyTitle: AppStrings.notifDailyReadyTitle,
        dailyReadyBody: AppStrings.notifDailyReadyBody,
        streakAtRiskTitle: AppStrings.notifStreakAtRiskTitle,
        streakAtRiskBody: AppStrings.notifStreakAtRiskBody,
      ),
    );
  }

  Future<void> recheckUpdate() async {
    final decision = await checkAppUpdate();
    if (isClosed) return;
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
    await appUpdateRepository.openStore(url);
  }

  Future<void> openGame(String gameId) {
    return analytics.logHomeGameOpened(gameId: gameId);
  }

  @override
  Future<void> close() {
    _refreshTimer?.cancel();
    return super.close();
  }
}
