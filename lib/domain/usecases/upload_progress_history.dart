import '../entities/game_day_record.dart';
import '../logic/local_game_day.dart';
import '../logic/progress_merge.dart';
import '../repositories/hint_quota_repository.dart';
import '../repositories/progress_local_repository.dart';
import '../repositories/progress_remote_repository.dart';
import '../repositories/score_repository.dart';

/// Outcome of one [UploadProgressHistory] call.
class UploadProgressHistoryResult {
  const UploadProgressHistoryResult({
    this.ran = false,
    this.written = 0,
    this.rejected = 0,
  });

  /// False when the history was already uploaded or the call was cancelled.
  final bool ran;

  /// Days written (missing remotely, or improving the remote copy).
  final int written;

  /// Days the rules rejected (skipped for good).
  final int rejected;

  @override
  String toString() =>
      'UploadProgressHistoryResult(ran: $ran, written: $written, '
      'rejected: $rejected)';
}

/// Uploads every daily clear on this device to `users/{uid}/game_days` once
/// per account, so stats see the days from before progress sync (which only
/// covers today and yesterday).
///
/// Each local clear is merged with the remote copy (`mergeGameDay`) and
/// written when the remote doc is missing or differs, so a write never
/// regresses what the server has. Writes go in batches of [batchSize]; the
/// rules' rejections are skipped. The `history_uploaded_{uid}` flag is set
/// only after every batch was committed, so an offline or failed run (which
/// throws) is retried by the next full sync.
class UploadProgressHistory {
  UploadProgressHistory({
    required this._scores,
    required this._hintQuota,
    required this._local,
    required this._remote,
  });

  static const batchSize = 400;

  final ScoreRepository _scores;
  final HintQuotaRepository _hintQuota;
  final ProgressLocalRepository _local;
  final ProgressRemoteRepository _remote;

  /// [isCancelled] is checked before each batch and before the flag is set
  /// (e.g. the signed-in account changed); a cancelled call returns without
  /// setting the flag.
  Future<UploadProgressHistoryResult> call(
    String uid, {
    bool Function()? isCancelled,
  }) async {
    if (uid.isEmpty || _local.isHistoryUploaded(uid)) {
      return const UploadProgressHistoryResult();
    }
    bool cancelled() => isCancelled?.call() ?? false;

    final localDays = readLocalDailyHistory(
      scores: _scores,
      hintQuota: _hintQuota,
    ).where((day) => day.cleared).toList();
    var pending = <GameDayRecord>[];
    if (localDays.isNotEmpty) {
      if (cancelled()) return const UploadProgressHistoryResult();
      final remoteDays = {
        // The server copy, never the offline cache: offline, the upload
        // fails fast instead of queueing writes against a stale view.
        for (final day in await _remote.fetchAllDays(
          uid: uid,
          fromServer: true,
        ))
          _key(day): day,
      };
      pending = [
        for (final day in localDays) ?_toWrite(day, remoteDays[_key(day)]),
      ];
    }

    var rejected = 0;
    for (var start = 0; start < pending.length; start += batchSize) {
      if (cancelled()) return const UploadProgressHistoryResult();
      final end = start + batchSize < pending.length
          ? start + batchSize
          : pending.length;
      rejected += await _remote.saveDayBatch(
        uid: uid,
        records: pending.sublist(start, end),
      );
    }
    if (cancelled()) return const UploadProgressHistoryResult();
    await _local.setHistoryUploaded(uid);
    return UploadProgressHistoryResult(
      ran: true,
      written: pending.length - rejected,
      rejected: rejected,
    );
  }

  /// The merged day when it adds to [remote]; null when [remote] already has
  /// it (or better).
  static GameDayRecord? _toWrite(GameDayRecord local, GameDayRecord? remote) {
    final merged = withLegacyClearFlags(mergeGameDay(local, remote));
    if (remote != null && daySignature(remote) == daySignature(merged)) {
      return null;
    }
    return merged;
  }

  static String _key(GameDayRecord day) => '${day.gameId}_${day.playId}';
}
