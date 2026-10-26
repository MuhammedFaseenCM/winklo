import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/entities/reminder_settings.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/habit/engagement_planner.dart';
import 'package:winklo/domain/habit/engagement_reminder.dart';
import 'package:winklo/domain/habit/game_habit_status.dart';
import 'package:winklo/domain/habit/weekly_recap.dart';
import 'package:winklo/domain/notification_types.dart';

void main() {
  // Thursday 15 October 2026.
  const today = '20261015';
  const yesterday = '20261014';
  final morning = DateTime(2026, 10, 15, 9);
  final lateEvening = DateTime(2026, 10, 15, 21);

  GameHabitStatus game(
    String gameId, {
    int current = 0,
    String? last,
    int freezes = 1,
    bool cleared = false,
  }) {
    return GameHabitStatus(
      streak: GameStreak(
        gameId: gameId,
        current: current,
        longest: current,
        lastClearedDateId: last,
        freezeCount: freezes,
      ),
      clearedToday: cleared,
    );
  }

  List<GameHabitStatus> idle() => [
    game(GameIds.zip),
    game(GameIds.pathWords),
    game(GameIds.sudoku),
  ];

  List<EngagementReminder> plan({
    ReminderSettings settings = const ReminderSettings(),
    List<GameHabitStatus>? games,
    DateTime? now,
    WeeklyRecap? recap,
  }) => EngagementPlanner.plan(
    settings: settings,
    games: games ?? idle(),
    now: now ?? morning,
    recap: recap,
  );

  List<StreakAtRiskReminder> streakReminders(List<EngagementReminder> all) =>
      all.whereType<StreakAtRiskReminder>().toList();

  List<DailyReadyReminder> mornings(List<EngagementReminder> all) =>
      all.whereType<DailyReadyReminder>().toList();

  group('morning reminders', () {
    test('a week of mornings, then day 10 and day 14', () {
      final all = mornings(plan());
      expect(all.map((r) => r.when), [
        for (final day in [16, 17, 18, 19, 20, 21, 22, 25, 29])
          DateTime(2026, 10, day, 8),
      ]);
      expect(all.map((r) => r.slot), [0, 1, 2, 3, 4, 5, 6, 7, 8]);
      expect(all.map((r) => r.id), [
        for (var slot = 0; slot < 9; slot++)
          NotificationTypes.scheduleIdMorningBase + slot,
      ]);
      expect(all.map((r) => r.phase), [
        MorningPhase.active,
        for (var i = 0; i < 6; i++) MorningPhase.lapsed,
        MorningPhase.missYou,
        MorningPhase.lastCall,
      ]);
    });

    test('starts today while today’s time is ahead', () {
      final all = mornings(
        plan(
          settings: const ReminderSettings(dailyReadyMinutes: 7 * 60 + 15),
          now: DateTime(2026, 10, 15, 6),
        ),
      );
      expect(all.first.when, DateTime(2026, 10, 15, 7, 15));
      expect(all.last.when, DateTime(2026, 10, 28, 7, 15));
    });

    test('with every game cleared today, starts tomorrow', () {
      final all = mornings(
        plan(
          now: DateTime(2026, 10, 15, 6),
          games: [
            game(GameIds.zip, cleared: true),
            game(GameIds.pathWords, current: 2, last: today),
            game(GameIds.sudoku, cleared: true),
          ],
        ),
      );
      expect(all.first.when, DateTime(2026, 10, 16, 8));
    });

    test('with a game left to play today, still starts today', () {
      final all = mornings(
        plan(
          now: DateTime(2026, 10, 15, 6),
          games: [
            game(GameIds.zip, cleared: true),
            game(GameIds.pathWords),
            game(GameIds.sudoku, cleared: true),
          ],
        ),
      );
      expect(all.first.when, DateTime(2026, 10, 15, 8));
    });

    test('this morning names the longest uncleared streak', () {
      final all = mornings(
        plan(
          now: DateTime(2026, 10, 15, 6),
          games: [
            game(GameIds.zip, current: 20, last: today, cleared: true),
            game(GameIds.pathWords, current: 5, last: yesterday),
            game(GameIds.sudoku, current: 4, last: yesterday),
          ],
        ),
      );
      expect(all.first.streakGameId, GameIds.pathWords);
      expect(all.first.streakDays, 5);
      expect(all.skip(1).map((r) => r.streakGameId), everyElement(isNull));
      expect(all.skip(1).map((r) => r.streakDays), everyElement(0));
    });

    test('tomorrow morning names what survives today', () {
      final all = mornings(
        plan(
          games: [
            game(GameIds.zip, current: 12, last: today, cleared: true),
            // Missed yesterday with no freeze left: gone by tomorrow.
            game(GameIds.pathWords, current: 30, last: yesterday, freezes: 0),
            game(GameIds.sudoku),
          ],
        ),
      );
      expect(all.first.when, DateTime(2026, 10, 16, 8));
      expect(all.first.streakGameId, GameIds.zip);
      expect(all.first.streakDays, 12);
    });

    test('a streak under three days is not named', () {
      final all = mornings(
        plan(
          games: [
            game(GameIds.zip, current: 2, last: today),
            ...idle().skip(1),
          ],
        ),
      );
      expect(all.first.streakGameId, isNull);
      expect(all.first.streakDays, 0);
    });

    test('ties go to Zip, Path Words, then Sudoku', () {
      final all = mornings(
        plan(
          now: DateTime(2026, 10, 15, 6),
          games: [
            game(GameIds.zip),
            game(GameIds.pathWords, current: 6, last: yesterday),
            game(GameIds.sudoku, current: 6, last: yesterday),
          ],
        ),
      );
      expect(all.first.streakGameId, GameIds.pathWords);
    });

    test('off schedules none', () {
      final reminders = plan(
        settings: const ReminderSettings(dailyReadyEnabled: false),
      );
      expect(mornings(reminders), isEmpty);
    });
  });

  group('streak at risk', () {
    test('names the longest uncleared streak tonight', () {
      final reminders = streakReminders(
        plan(
          games: [
            game(GameIds.zip, current: 12, last: yesterday),
            game(GameIds.pathWords),
            game(GameIds.sudoku, current: 3, last: yesterday),
          ],
        ),
      );
      final tonight = reminders.first;
      expect(tonight.id, NotificationTypes.scheduleIdStreakAtRisk);
      expect(tonight.when, DateTime(2026, 10, 15, 20));
      expect(tonight.gameId, GameIds.zip);
      expect(tonight.days, 12);
      expect(tonight.others, 1);
    });

    test('ties go to Zip, Path Words, then Sudoku', () {
      final tonight = streakReminders(
        plan(
          games: [
            game(GameIds.zip),
            game(GameIds.pathWords, current: 4, last: yesterday),
            game(GameIds.sudoku, current: 4, last: yesterday),
          ],
        ),
      ).first;
      expect(tonight.gameId, GameIds.pathWords);
      expect(tonight.others, 1);
    });

    test('a streak on a freeze today is at risk tonight', () {
      final tonight = streakReminders(
        plan(
          games: [
            game(GameIds.zip, current: 6, last: '20261013'),
            game(GameIds.pathWords),
            game(GameIds.sudoku),
          ],
        ),
      ).first;
      expect(tonight.gameId, GameIds.zip);
      expect(tonight.days, 6);
    });

    test('no streak on any uncleared game: nothing tonight', () {
      expect(streakReminders(plan()), isEmpty);
      expect(
        streakReminders(
          plan(
            games: [
              game(GameIds.zip, current: 5, last: today, cleared: true),
              game(GameIds.pathWords),
              game(GameIds.sudoku),
            ],
          ),
        ).where((r) => r.when.day == 15),
        isEmpty,
      );
    });

    test('a game cleared today is never at risk tonight', () {
      // The streak says today even when the score lookup disagrees.
      final reminders = streakReminders(
        plan(
          games: [
            game(GameIds.zip, current: 5, last: today),
            game(GameIds.pathWords),
            game(GameIds.sudoku),
          ],
        ),
      );
      expect(reminders.where((r) => r.when.day == 15), isEmpty);
    });

    test('with every game cleared, reminds tomorrow evening', () {
      final reminders = streakReminders(
        plan(
          games: [
            game(GameIds.zip, current: 9, last: today, cleared: true),
            game(GameIds.pathWords, current: 2, last: today, cleared: true),
            game(GameIds.sudoku, cleared: true),
          ],
        ),
      );
      final tomorrow = reminders.single;
      expect(tomorrow.id, NotificationTypes.scheduleIdStreakAtRiskTomorrow);
      expect(tomorrow.when, DateTime(2026, 10, 16, 20));
      expect(tomorrow.gameId, GameIds.zip);
      expect(tomorrow.days, 9);
      expect(tomorrow.others, 1);
    });

    test('tonight and tomorrow are both planned', () {
      final reminders = streakReminders(
        plan(
          games: [
            game(GameIds.zip, current: 12, last: yesterday),
            game(GameIds.pathWords, current: 3, last: today, cleared: true),
            game(GameIds.sudoku),
          ],
        ),
      );
      expect(reminders, hasLength(2));
      // Tonight: Zip (12). Tomorrow, if today passes unplayed: Zip carried by
      // its freeze and Path Words, cleared today.
      expect(reminders[0].when, DateTime(2026, 10, 15, 20));
      expect((reminders[0].gameId, reminders[0].others), (GameIds.zip, 0));
      expect(reminders[1].when, DateTime(2026, 10, 16, 20));
      expect((reminders[1].gameId, reminders[1].others), (GameIds.zip, 1));
    });

    test('after tonight’s time, only tomorrow’s stakes are planned', () {
      final reminders = streakReminders(
        plan(
          now: lateEvening,
          games: [
            game(GameIds.zip, current: 12, last: yesterday, freezes: 0),
            game(GameIds.pathWords, current: 3, last: yesterday),
            game(GameIds.sudoku),
          ],
        ),
      );
      // Zip has no freeze, so it would be gone by tomorrow.
      final tomorrow = reminders.single;
      expect(tomorrow.when, DateTime(2026, 10, 16, 20));
      expect(tomorrow.gameId, GameIds.pathWords);
      expect(tomorrow.days, 3);
      expect(tomorrow.others, 0);
    });

    test('nothing at stake tonight or tomorrow: none at all', () {
      final reminders = streakReminders(
        plan(
          now: lateEvening,
          games: [
            game(GameIds.zip, current: 4, last: '20261013'),
            game(GameIds.pathWords),
            game(GameIds.sudoku),
          ],
        ),
      );
      expect(reminders, isEmpty);
    });

    test('uses the chosen time', () {
      final reminders = streakReminders(
        plan(
          settings: const ReminderSettings(streakReminderMinutes: 21 * 60 + 30),
          now: lateEvening,
          games: [
            game(GameIds.zip, current: 2, last: yesterday),
            game(GameIds.pathWords),
            game(GameIds.sudoku),
          ],
        ),
      );
      expect(reminders.first.when, DateTime(2026, 10, 15, 21, 30));
    });

    test('off schedules none', () {
      final reminders = plan(
        settings: const ReminderSettings(streakAtRiskEnabled: false),
        games: [
          game(GameIds.zip, current: 12, last: yesterday),
          game(GameIds.pathWords),
          game(GameIds.sudoku),
        ],
      );
      expect(streakReminders(reminders), isEmpty);
    });
  });

  group('weekly recap', () {
    const recap = WeeklyRecap(
      weekStartId: '20261012',
      cleared: 18,
      possible: 21,
      bestGameId: GameIds.zip,
      bestSeconds: 58,
      streakGameId: GameIds.sudoku,
      streakDays: 5,
    );

    test('next Sunday an hour before the streak time', () {
      final weekly = plan(recap: recap).whereType<WeeklyRecapReminder>().single;
      expect(weekly.when, DateTime(2026, 10, 18, 19));
      expect(weekly.recap, recap);
      expect(weekly.id, NotificationTypes.scheduleIdWeeklyRecap);
    });

    test('nextWeeklyRecapAt on a Sunday after the time is next week', () {
      expect(
        EngagementPlanner.nextWeeklyRecapAt(
          const ReminderSettings(),
          DateTime(2026, 10, 18, 19, 5),
        ),
        DateTime(2026, 10, 25, 19),
      );
    });

    test('a 00:30 streak time puts the recap at 00:00 Sunday', () {
      expect(
        EngagementPlanner.nextWeeklyRecapAt(
          const ReminderSettings(streakReminderMinutes: 30),
          morning,
        ),
        DateTime(2026, 10, 18),
      );
    });

    test('a recap with no clears is skipped', () {
      const empty = WeeklyRecap(
        weekStartId: '20261012',
        cleared: 0,
        possible: 21,
      );
      expect(plan(recap: empty).whereType<WeeklyRecapReminder>(), isEmpty);
      expect(plan().whereType<WeeklyRecapReminder>(), isEmpty);
    });

    test('off schedules none', () {
      final reminders = plan(
        settings: const ReminderSettings(weeklyRecapEnabled: false),
        recap: recap,
      );
      expect(reminders.whereType<WeeklyRecapReminder>(), isEmpty);
    });
  });

  test('every planned reminder has its own id', () {
    final reminders = plan(
      games: [
        game(GameIds.zip, current: 12, last: yesterday),
        game(GameIds.pathWords, current: 3, last: today, cleared: true),
        game(GameIds.sudoku),
      ],
      recap: const WeeklyRecap(
        weekStartId: '20261012',
        cleared: 3,
        possible: 21,
      ),
    );
    expect(reminders, hasLength(12));
    expect(reminders.map((r) => r.id).toSet(), hasLength(12));
    // Every id a replan cancels, except the old daily repeat's.
    expect(
      reminders.map((r) => r.id).toSet(),
      {...NotificationTypes.engagementScheduleIds}
        ..remove(NotificationTypes.scheduleIdDailyReadyLegacy),
    );
  });
}
