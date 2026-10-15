import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/entities/reminder_settings.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/habit/engagement_reminder.dart';
import 'package:winklo/domain/habit/home_widget_snapshot.dart';
import 'package:winklo/domain/repositories/home_widget_repository.dart';
import 'package:winklo/domain/repositories/notification_repository.dart';
import 'package:winklo/domain/repositories/score_repository.dart';
import 'package:winklo/domain/repositories/settings_repository.dart';
import 'package:winklo/domain/usecases/get_streak.dart';
import 'package:winklo/domain/usecases/get_weekly_recap.dart';
import 'package:winklo/domain/usecases/refresh_habit_surfaces.dart';
import 'package:winklo/domain/usecases/schedule_engagement_notifications.dart';

class _MockGetStreak extends Mock implements GetStreak {}

class _MockScores extends Mock implements ScoreRepository {}

class _MockSettings extends Mock implements SettingsRepository {}

class _MockNotifications extends Mock implements NotificationRepository {}

class _MockHomeWidget extends Mock implements HomeWidgetRepository {}

void main() {
  late _MockGetStreak getStreak;
  late _MockScores scores;
  late _MockSettings settings;
  late _MockNotifications notifications;
  late _MockHomeWidget homeWidget;
  // Thursday 15 October 2026, morning.
  final now = DateTime(2026, 10, 15, 9);

  setUpAll(() {
    registerFallbackValue(<EngagementReminder>[]);
    registerFallbackValue(
      const HomeWidgetSnapshot(
        dayId: '',
        nextDayId: '',
        today: [],
        tomorrow: [],
      ),
    );
  });

  setUp(() {
    getStreak = _MockGetStreak();
    scores = _MockScores();
    settings = _MockSettings();
    notifications = _MockNotifications();
    homeWidget = _MockHomeWidget();
    when(() => settings.reminders).thenReturn(const ReminderSettings());
    when(() => scores.getBestPoints(any())).thenReturn(0);
    when(() => scores.getBestTimeSeconds(any())).thenReturn(null);
    when(
      () => getStreak(
        gameId: any(named: 'gameId'),
        now: any(named: 'now'),
      ),
    ).thenAnswer(
      (inv) async => GameStreak(gameId: inv.namedArguments[#gameId] as String),
    );
    when(
      () => notifications.replaceEngagementSchedules(any()),
    ).thenAnswer((_) async {});
    when(() => homeWidget.update(any())).thenAnswer((_) async {});
  });

  RefreshHabitSurfaces build() => RefreshHabitSurfaces(
    getStreak: getStreak,
    scores: scores,
    settings: settings,
    schedule: ScheduleEngagementNotifications(notifications),
    weeklyRecap: GetWeeklyRecap(scores),
    homeWidget: homeWidget,
    now: () => now,
  );

  test('plans from decayed streaks and today’s clears', () async {
    when(
      () => getStreak(
        gameId: GameIds.zip,
        now: any(named: 'now'),
      ),
    ).thenAnswer(
      (_) async => const GameStreak(
        gameId: GameIds.zip,
        current: 12,
        longest: 12,
        lastClearedDateId: '20261014',
      ),
    );
    when(() => scores.getBestTimeSeconds('zip_daily_20261013')).thenReturn(61);

    await build()();

    final reminders =
        verify(
              () => notifications.replaceEngagementSchedules(captureAny()),
            ).captured.single
            as List<EngagementReminder>;
    final streak = reminders.whereType<StreakAtRiskReminder>().first;
    expect(streak.gameId, GameIds.zip);
    expect(streak.days, 12);
    expect(streak.when, DateTime(2026, 10, 15, 20));
    final recap = reminders.whereType<WeeklyRecapReminder>().single;
    expect(recap.when, DateTime(2026, 10, 18, 19));
    expect(recap.recap.weekStartId, '20261012');
    expect(recap.recap.cleared, 1);
    expect(recap.recap.streakDays, 12);
    verify(() => getStreak(gameId: GameIds.zip, now: now)).called(1);
  });

  test('today’s score lookup decides what is cleared', () async {
    when(
      () => getStreak(
        gameId: GameIds.sudoku,
        now: any(named: 'now'),
      ),
    ).thenAnswer(
      (_) async => const GameStreak(
        gameId: GameIds.sudoku,
        current: 3,
        longest: 3,
        lastClearedDateId: '20261014',
      ),
    );
    when(() => scores.getBestPoints('sudoku_20261015')).thenReturn(880);

    await build()();

    final snapshot =
        verify(() => homeWidget.update(captureAny())).captured.single
            as HomeWidgetSnapshot;
    expect(snapshot.dayId, '20261015');
    expect(snapshot.today.map((line) => line.mark), [
      HomeWidgetMark.play,
      HomeWidgetMark.play,
      HomeWidgetMark.cleared,
    ]);
  });

  test('uses the saved reminder settings', () async {
    when(() => settings.reminders).thenReturn(
      const ReminderSettings(
        dailyReadyEnabled: false,
        streakAtRiskEnabled: false,
        weeklyRecapEnabled: false,
      ),
    );
    await build()();
    verify(() => notifications.replaceEngagementSchedules(const [])).called(1);
  });

  test('overlapping calls run one after another, once more at most', () async {
    final gate = Completer<void>();
    var runs = 0;
    when(() => notifications.replaceEngagementSchedules(any())).thenAnswer((
      _,
    ) async {
      runs++;
      if (runs == 1) await gate.future;
    });
    final refresh = build();

    final first = refresh();
    await Future<void>.delayed(Duration.zero);
    final second = refresh();
    final third = refresh();
    expect(runs, 1);

    gate.complete();
    await Future.wait([first, second, third]);
    expect(runs, 2);
  });

  test('a failing run fails its callers and the next run still goes', () async {
    when(
      () => getStreak(
        gameId: any(named: 'gameId'),
        now: any(named: 'now'),
      ),
    ).thenThrow(StateError('prefs'));
    final refresh = build();
    await expectLater(refresh(), throwsStateError);

    when(
      () => getStreak(
        gameId: any(named: 'gameId'),
        now: any(named: 'now'),
      ),
    ).thenAnswer(
      (inv) async => GameStreak(gameId: inv.namedArguments[#gameId] as String),
    );
    await refresh();
    verify(() => homeWidget.update(any())).called(1);
  });
}
