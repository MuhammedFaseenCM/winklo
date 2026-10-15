import 'dart:async';

import '../game_ids.dart';
import '../habit/engagement_planner.dart';
import '../habit/game_habit_status.dart';
import '../habit/home_widget_snapshot.dart';
import '../habit/weekly_recap.dart';
import '../logic/progress_merge.dart';
import '../play_period.dart';
import '../repositories/home_widget_repository.dart';
import '../repositories/score_repository.dart';
import '../repositories/settings_repository.dart';
import 'get_streak.dart';
import 'get_weekly_recap.dart';
import 'schedule_engagement_notifications.dart';

/// Brings the reminders and the home-screen widget up to date with today's
/// streaks and clears.
///
/// Runs are serialized: a call made while one runs waits for one more run
/// (shared by every call made meanwhile), so two plans never interleave
/// their cancels and schedules. A failed run fails the calls it served.
class RefreshHabitSurfaces {
  RefreshHabitSurfaces({
    required this._getStreak,
    required this._scores,
    required this._settings,
    required this._schedule,
    required this._weeklyRecap,
    required this._homeWidget,
    this._playPeriod = PlayPeriod.daily,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const gameIds = [GameIds.zip, GameIds.pathWords, GameIds.sudoku];

  final GetStreak _getStreak;
  final ScoreRepository _scores;
  final SettingsRepository _settings;
  final ScheduleEngagementNotifications _schedule;
  final GetWeeklyRecap _weeklyRecap;
  final HomeWidgetRepository _homeWidget;
  final Duration _playPeriod;
  final DateTime Function() _now;

  bool _running = false;
  Completer<void>? _rerun;

  Future<void> call() {
    if (_running) return (_rerun ??= Completer<void>()).future;
    _running = true;
    final first = Completer<void>();
    unawaited(_drive(first));
    return first.future;
  }

  Future<void> _drive(Completer<void> first) async {
    var completer = first;
    while (true) {
      try {
        await _run();
        completer.complete();
      } catch (e, st) {
        completer.completeError(e, st);
      }
      final next = _rerun;
      if (next == null) break;
      _rerun = null;
      completer = next;
    }
    _running = false;
  }

  Future<void> _run() async {
    final now = _now();
    final periodId = PlayPeriod.id(now, _playPeriod);
    final games = <GameHabitStatus>[];
    for (final gameId in gameIds) {
      // Decays (and stores the decay of) a lapsed streak, as Home does.
      final streak = await _getStreak(gameId: gameId, now: now);
      final key = modeKeyFor(gameId, periodId);
      games.add(
        GameHabitStatus(
          streak: streak,
          clearedToday:
              _scores.getBestPoints(key) > 0 ||
              _scores.getBestTimeSeconds(key) != null,
        ),
      );
    }

    final settings = _settings.reminders;
    final recap = _weeklyRecap(
      weekStart: WeeklyRecap.weekStart(
        EngagementPlanner.nextWeeklyRecapAt(settings, now),
      ),
      currentStreaks: {
        for (final game in games) game.gameId: game.streak.current,
      },
    );
    await _schedule(settings: settings, games: games, now: now, recap: recap);
    await _homeWidget.update(HomeWidgetSnapshot.build(games: games, now: now));
  }
}
