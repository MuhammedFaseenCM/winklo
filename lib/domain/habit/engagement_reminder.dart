import '../notification_types.dart';
import 'weekly_recap.dart';

/// A local notification to schedule, without its copy (the data layer words
/// it).
sealed class EngagementReminder {
  const EngagementReminder({required this.when});

  /// Local time it fires (the first time, for a daily repeat).
  final DateTime when;

  int get id;
  String get type;
  bool get repeatsDaily => false;
}

/// "Today’s puzzles are ready", every day at the chosen time.
final class DailyReadyReminder extends EngagementReminder {
  const DailyReadyReminder({required super.when});

  @override
  int get id => NotificationTypes.scheduleIdDailyReady;

  @override
  String get type => NotificationTypes.dailyReady;

  @override
  bool get repeatsDaily => true;

  @override
  bool operator ==(Object other) =>
      other is DailyReadyReminder && other.when == when;

  @override
  int get hashCode => when.hashCode;
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
