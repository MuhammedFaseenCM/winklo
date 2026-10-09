import 'progress_merge.dart';

/// Whether a run started in period [playId] may still be finished at [now].
///
/// A run carries over into the next period, so a game left open past midnight
/// still counts for its own day; it doesn't carry further, so a draft left
/// behind for days never comes back.
bool canFinishRun(String playId, DateTime now, Duration period) =>
    syncWindowPlayIds(now, period).contains(playId);
