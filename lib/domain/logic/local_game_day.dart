import '../entities/game_day_record.dart';
import '../game_ids.dart';
import '../repositories/hint_quota_repository.dart';
import '../repositories/score_repository.dart';
import 'progress_merge.dart';

/// Games with daily progress, a daily board and a `game_days` doc per period.
const dailyProgressGameIds = [GameIds.zip, GameIds.pathWords, GameIds.sudoku];

/// This device's copy of one daily period of [gameId], read from the daily
/// mode key ([modeKeyFor]) and the hint quota.
///
/// A cleared day carries its stored clean-run flags, or the conservative
/// legacy guess ([withLegacyClearFlags]) when there are none.
GameDayRecord readLocalGameDay({
  required ScoreRepository scores,
  required HintQuotaRepository hintQuota,
  required String gameId,
  required String playId,
}) {
  final modeKey = modeKeyFor(gameId, playId);
  final time = scores.getBestTimeSeconds(modeKey);
  final points = scores.getBestPoints(modeKey);
  final record = GameDayRecord(
    gameId: gameId,
    playId: playId,
    timeSeconds: time,
    points: points > 0 ? points : null,
    hintsUsed: hintQuota.usedFor(gameId, playId),
  );
  if (time == null) return record;

  final cleared = record.copyWith(board: scores.getClearBoard(modeKey));
  final meta = scores.getClearMeta(modeKey);
  if (meta != null) {
    return cleared.copyWith(
      usedHints: meta.usedHints,
      hadMistakes: meta.hadMistakes,
      flagsKnown: true,
    );
  }
  return withLegacyClearFlags(cleared);
}

/// Every cleared daily period of the [dailyProgressGameIds] stored on this
/// device (daily mode keys only), by game then period.
List<GameDayRecord> readLocalDailyHistory({
  required ScoreRepository scores,
  required HintQuotaRepository hintQuota,
}) => [
  for (final gameId in dailyProgressGameIds)
    for (final playId in scores.dailyPlayIds(gameId))
      readLocalGameDay(
        scores: scores,
        hintQuota: hintQuota,
        gameId: gameId,
        playId: playId,
      ),
];

/// Cleared records without real flags get the conservative legacy guess
/// ([legacyClearFlags], recomputed from [GameDayRecord.hintsUsed]).
GameDayRecord withLegacyClearFlags(GameDayRecord record) {
  if (!record.cleared || record.flagsKnown == true) return record;
  final flags = legacyClearFlags(record.gameId, record.hintsUsed);
  return record.copyWith(
    usedHints: flags.usedHints,
    hadMistakes: flags.hadMistakes,
    flagsKnown: false,
  );
}
