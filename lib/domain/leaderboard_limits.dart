import 'game_ids.dart';

/// Fastest clear each board accepts, in whole seconds.
///
/// Zip's floor is set by its smallest board: a 6×6 daily with few numbers is
/// traced honestly in about 6 s (2026-10-19), so 10 s turned real clears
/// away; the Worker's proof check is what stops a forged path.
///
/// The same numbers are `MIN_SECONDS` in workers/leaderboard/src/limits.ts
/// and `minLeaderboardSeconds` in firestore/firestore.rules;
/// test/firestore/leaderboard_fair_play_pins_test.dart pins all three.
const leaderboardMinSeconds = <String, int>{
  GameIds.zip: 3,
  GameIds.pathWords: 15,
  GameIds.sudoku: 15,
};

/// Slowest clear the Worker accepts: one day.
const leaderboardMaxSeconds = 86400;

/// The most rows a daily board query returns; a board this long may have
/// more players than it shows.
const leaderboardDailyLimit = 50;

/// Whether a [timeSeconds] clear of [gameId] can go on a board at all.
bool leaderboardAcceptsTime(String gameId, int timeSeconds) {
  final min = leaderboardMinSeconds[gameId];
  return min != null &&
      timeSeconds >= min &&
      timeSeconds <= leaderboardMaxSeconds;
}

/// Hours before a day's UTC midnight that its board opens (00:00 at UTC+14).
const leaderboardLiveFromHoursBefore = 14;

/// Hours after a day's UTC midnight that its board closes (24:00 at UTC-12).
const leaderboardLiveUntilHoursAfter = 36;

final _dayIdPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Whether the board for [dayId] (`yyyy-MM-dd`, the phone's local date) still
/// takes times at [now]: from 10:00 UTC the day before to 12:00 UTC the day
/// after, as the rules and the Worker check.
bool leaderboardDayIsLive(String dayId, DateTime now) {
  final match = _dayIdPattern.firstMatch(dayId);
  if (match == null) return false;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final midnight = DateTime.utc(year, month, day);
  if (midnight.year != year || midnight.month != month || midnight.day != day) {
    return false;
  }
  final t = now.toUtc();
  final opens = midnight.subtract(
    const Duration(hours: leaderboardLiveFromHoursBefore),
  );
  final closes = midnight.add(
    const Duration(hours: leaderboardLiveUntilHoursAfter),
  );
  return !t.isBefore(opens) && t.isBefore(closes);
}
