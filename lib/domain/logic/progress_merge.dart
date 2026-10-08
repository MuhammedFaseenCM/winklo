import '../app_calendar.dart';
import '../entities/clear_meta.dart';
import '../entities/game_day_record.dart';
import '../entities/game_streak.dart';
import '../game_ids.dart';
import '../play_period.dart';

// Pure merge / key helpers for local <-> remote progress sync.

final _playIdPattern = RegExp(r'^[0-9]{8}([0-9]{4})?$');

/// Merges two copies of one game day.
///
/// Time = min, points = max, hintsUsed = max, clearedAt = earliest. Clean-run
/// flags come from the side whose time won; on a tie the side with
/// `flagsKnown == true` wins, then [local]. The board also follows the time;
/// on a tie [remote]'s wins when it has one (the rules only let a stored board
/// change with a better time, so the first board pushed stays). Ids are taken
/// from [local].
GameDayRecord mergeGameDay(GameDayRecord local, GameDayRecord? remote) {
  if (remote == null) return local;

  final flagsFrom = _flagsWinner(local, remote);
  return GameDayRecord(
    gameId: local.gameId,
    playId: local.playId,
    timeSeconds: _minOrNull(local.timeSeconds, remote.timeSeconds),
    points: _maxOrNull(local.points, remote.points),
    usedHints: flagsFrom.usedHints,
    hadMistakes: flagsFrom.hadMistakes,
    flagsKnown: flagsFrom.flagsKnown,
    hintsUsed: local.hintsUsed > remote.hintsUsed
        ? local.hintsUsed
        : remote.hintsUsed,
    clearedAt: _earliest(local.clearedAt, remote.clearedAt),
    board: _boardWinner(local, remote).board,
  );
}

GameDayRecord _boardWinner(GameDayRecord local, GameDayRecord remote) {
  final lt = local.timeSeconds;
  final rt = remote.timeSeconds;
  if (lt == null && rt == null) return local;
  if (lt == null) return remote;
  if (rt == null) return local;
  if (lt != rt) return lt < rt ? local : remote;
  return remote.board == null ? local : remote;
}

GameDayRecord _flagsWinner(GameDayRecord local, GameDayRecord remote) {
  final lt = local.timeSeconds;
  final rt = remote.timeSeconds;
  if (lt == null && rt == null) return local;
  if (lt == null) return remote;
  if (rt == null) return local;
  if (lt != rt) return lt < rt ? local : remote;
  if (local.flagsKnown != true && remote.flagsKnown == true) return remote;
  return local;
}

/// Merges two copies of one game's streak.
///
/// The copy with the later `lastClearedDateId` wins (null is oldest); a tie
/// goes to the higher `current`, then [local]. `longest` is the max of both
/// copies and the winning `current`.
GameStreak mergeStreak(GameStreak local, GameStreak? remote) {
  if (remote == null) return local;

  final winner = _streakWinner(local, remote);
  var longest = local.longest > remote.longest ? local.longest : remote.longest;
  if (winner.current > longest) longest = winner.current;
  return GameStreak(
    gameId: local.gameId,
    current: winner.current,
    longest: longest,
    lastClearedDateId: winner.lastClearedDateId,
    freezeAvailable: winner.freezeAvailable,
  );
}

GameStreak _streakWinner(GameStreak local, GameStreak remote) {
  final byDay = _compareDateIds(
    local.lastClearedDateId,
    remote.lastClearedDateId,
  );
  if (byDay != 0) return byDay > 0 ? local : remote;
  if (remote.current > local.current) return remote;
  return local;
}

/// Null sorts before any date id; `YYYYMMDD` ids compare as strings.
int _compareDateIds(String? a, String? b) {
  if (a == b) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  return a.compareTo(b);
}

/// Score-repository mode key for a daily game period. Must match the keys the
/// game blocs and `HomeCubit` build (`zip_${level.id}` with
/// `level.id == 'daily_<playId>'`, `path_words_<playId>`, `sudoku_<playId>`).
///
/// Throws [ArgumentError] for games without a daily board.
String modeKeyFor(String gameId, String playId) {
  switch (gameId) {
    case GameIds.zip:
      return 'zip_daily_$playId';
    case GameIds.pathWords:
      return 'path_words_$playId';
    case GameIds.sudoku:
      return 'sudoku_$playId';
  }
  throw ArgumentError.value(gameId, 'gameId', 'No daily progress for game');
}

/// Daily leaderboard day (`yyyy-MM-dd`) a period's clear belongs to: the
/// first 8 chars of [playId] (`YYYYMMDD` or debug `YYYYMMDDHHmm`).
///
/// Throws [ArgumentError] when [playId] is not a play-period id.
String leaderboardDayIdForPlayId(String playId) {
  if (!_playIdPattern.hasMatch(playId)) {
    throw ArgumentError.value(playId, 'playId', 'Not a play-period id');
  }
  return '${playId.substring(0, 4)}-${playId.substring(4, 6)}-'
      '${playId.substring(6, 8)}';
}

/// Play ids the sync covers: the previous period, then the current one
/// (deduplicated).
///
/// Day-or-longer periods step back in local calendar days rather than a fixed
/// [Duration], so a 23 / 25-hour DST day never skips or repeats a day.
List<String> syncWindowPlayIds(DateTime now, Duration period) {
  final current = PlayPeriod.id(now, period);
  final DateTime previousInstant;
  if (PlayPeriod.isSubDaily(period)) {
    previousInstant = now.subtract(period);
  } else {
    final local = AppCalendar.localWallClock(now);
    // Noon avoids zones whose DST change skips local midnight.
    previousInstant = DateTime(
      local.year,
      local.month,
      local.day - period.inDays,
      12,
    );
  }
  final previous = PlayPeriod.id(previousInstant, period);
  return previous == current ? [current] : [previous, current];
}

/// Clean-run flags for a clear made before flags were stored locally.
///
/// `usedHints` is true when any hint quota was consumed that period (0 means
/// certainly no hints). `hadMistakes` is false for Zip / Path Words (no
/// mistake concept) and conservatively true for Sudoku.
ClearMeta legacyClearFlags(String gameId, int hintsUsed) {
  return ClearMeta(
    usedHints: hintsUsed > 0,
    hadMistakes: gameId == GameIds.sudoku,
  );
}

/// Stable signature of the synced fields of a day record, for "last pushed"
/// markers. Excludes ids (they are in the marker key) and `clearedAt`
/// (assigned remotely, never changes the pushed state).
String daySignature(GameDayRecord record) {
  return [
    't=${record.timeSeconds ?? '-'}',
    'p=${record.points ?? '-'}',
    'h=${_boolSig(record.usedHints)}',
    'm=${_boolSig(record.hadMistakes)}',
    'k=${_boolSig(record.flagsKnown)}',
    'u=${record.hintsUsed}',
    'b=${record.board ?? '-'}',
  ].join('|');
}

/// Stable signature of the synced fields of a streak (not `isOnFreeze`,
/// which is display-only).
String streakSignature(GameStreak streak) {
  return [
    'c=${streak.current}',
    'l=${streak.longest}',
    'd=${streak.lastClearedDateId ?? '-'}',
    'f=${_boolSig(streak.freezeAvailable)}',
  ].join('|');
}

String _boolSig(bool? value) => switch (value) {
  true => '1',
  false => '0',
  null => '-',
};

int? _minOrNull(int? a, int? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a < b ? a : b;
}

int? _maxOrNull(int? a, int? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a > b ? a : b;
}

DateTime? _earliest(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isBefore(b) ? a : b;
}
