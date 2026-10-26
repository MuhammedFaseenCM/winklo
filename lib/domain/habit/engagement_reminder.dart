import '../notification_types.dart';
import 'weekly_recap.dart';

/// A local notification to schedule, without its copy (the data layer words
/// it).
sealed class EngagementReminder {
  const EngagementReminder({required this.when});

  /// Local time it fires. Every reminder is a one-off: a repeat would show
  /// the same words every time.
  final DateTime when;

  int get id;
  String get type;
}

/// Where a morning reminder sits in the taper after the last app open.
enum MorningPhase {
  /// The next morning: what a player who opens the app daily always gets.
  active,

  /// Mornings 2–7: at least one day went by without an open.
  lapsed,

  /// Day 10.
  missYou,

  /// Day 14, the last one: says the reminders are pausing.
  lastCall,
}

/// One morning's "come play" reminder, at the chosen daily time.
final class DailyReadyReminder extends EngagementReminder {
  const DailyReadyReminder({
    required super.when,
    required this.slot,
    required this.phase,
    this.streakGameId,
    this.streakDays = 0,
  });

  /// Its index in `EngagementPlanner.morningOffsets`.
  final int slot;
  final MorningPhase phase;

  /// The longest streak still alive that morning, when it is long enough to
  /// mention (active mornings only).
  final String? streakGameId;
  final int streakDays;

  @override
  int get id => NotificationTypes.scheduleIdMorningBase + slot;

  @override
  String get type => NotificationTypes.dailyReady;

  @override
  bool operator ==(Object other) =>
      other is DailyReadyReminder &&
      other.when == when &&
      other.slot == slot &&
      other.phase == phase &&
      other.streakGameId == streakGameId &&
      other.streakDays == streakDays;

  @override
  int get hashCode => Object.hash(when, slot, phase, streakGameId, streakDays);

  @override
  String toString() =>
      'DailyReadyReminder($slot ${phase.name}, $when, $streakGameId $streakDays)';
}

/// "Your 12-day Zip streak ends at midnight" (and [others] more).
final class StreakAtRiskReminder extends EngagementReminder {
  const StreakAtRiskReminder({
    required super.when,
    required this.id,
    required this.gameId,
    required this.days,
    this.others = 0,
  });

  @override
  final int id;

  /// The longest streak at stake.
  final String gameId;
  final int days;

  /// Other games with a streak at stake that evening.
  final int others;

  @override
  String get type => NotificationTypes.streakAtRisk;

  @override
  bool operator ==(Object other) =>
      other is StreakAtRiskReminder &&
      other.when == when &&
      other.id == id &&
      other.gameId == gameId &&
      other.days == days &&
      other.others == others;

  @override
  int get hashCode => Object.hash(when, id, gameId, days, others);

  @override
  String toString() =>
      'StreakAtRiskReminder($id, $when, $gameId $days +$others)';
}

/// Sunday's "This week: 18 of 21 cleared, …".
final class WeeklyRecapReminder extends EngagementReminder {
  const WeeklyRecapReminder({required super.when, required this.recap});

  final WeeklyRecap recap;

  @override
  int get id => NotificationTypes.scheduleIdWeeklyRecap;

  @override
  String get type => NotificationTypes.weeklyRecap;

  @override
  bool operator ==(Object other) =>
      other is WeeklyRecapReminder &&
      other.when == when &&
      other.recap == recap;

  @override
  int get hashCode => Object.hash(when, recap);
}
