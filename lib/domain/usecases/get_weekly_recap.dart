import '../game_ids.dart';
import '../habit/weekly_recap.dart';
import '../logic/progress_merge.dart';
import '../repositories/score_repository.dart';

/// The daily clears of one week, from the scores stored on the device.
class GetWeeklyRecap {
  GetWeeklyRecap(this._scores);

  final ScoreRepository _scores;

  static const gameIds = [GameIds.zip, GameIds.pathWords, GameIds.sudoku];

  /// [weekStart] is a Monday; [currentStreaks] are each game's streak now.
  WeeklyRecap call({
    required DateTime weekStart,
    required Map<String, int> currentStreaks,
  }) {
    return WeeklyRecap.build(
      weekStart: weekStart,
      gameIds: gameIds,
      clearedOn: (gameId, dateId) {
        final key = modeKeyFor(gameId, dateId);
        return _scores.getBestPoints(key) > 0 ||
            _scores.getBestTimeSeconds(key) != null;
      },
      timeOn: (gameId, dateId) =>
          _scores.getBestTimeSeconds(modeKeyFor(gameId, dateId)),
      currentStreaks: currentStreaks,
    );
  }
}
