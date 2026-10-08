import 'dart:async';

import '../entities/client_error_report.dart';
import '../entities/clear_meta.dart';
import '../entities/game_day_record.dart';
import '../entities/game_streak.dart';
import '../game_ids.dart';
import '../logic/progress_merge.dart';
import '../repositories/auth_repository.dart';
import '../repositories/hint_quota_repository.dart';
import '../repositories/leaderboard_repository.dart';
import '../repositories/progress_local_repository.dart';
import '../repositories/progress_remote_repository.dart';
import '../repositories/score_repository.dart';
import '../repositories/streak_repository.dart';
import '../streak_calculator.dart';
import 'report_client_error.dart';

/// Outcome of one [SyncProgress] run.
class SyncProgressResult {
  const SyncProgressResult({this.localChanged = false, this.failures = 0});

  /// Local progress was purged or restored from the remote copy (Home should
  /// reload).
  final bool localChanged;

  /// Items (streak, day doc, leaderboard submit, ownership) that failed and
  /// will be retried on the next run.
  final int failures;

  @override
  bool operator ==(Object other) =>
      other is SyncProgressResult &&
      other.localChanged == localChanged &&
      other.failures == failures;

  @override
  int get hashCode => Object.hash(localChanged, failures);

  @override
  String toString() =>
      'SyncProgressResult(localChanged: $localChanged, failures: $failures)';
}

/// Reconciles local progress (SharedPreferences, read synchronously by the UI)
/// with the user's private remote copy, then backfills the daily leaderboards.
///
/// Per run: ownership (claim / stash + purge on account switch) -> the
/// current period's days -> streaks -> the previous period's days (pull +
/// merge, restore local, push) -> leaderboard for each cleared day. Restores
/// come first so the sign-in gate (`ensureSignedInForPlay`) sees today's
/// locks as early as possible. Every item is best-effort; "last pushed"
/// markers are written only after the remote write succeeded, so failures
/// retry next run. A run stops (without counting failures) as soon as the
/// signed-in account is no longer the one it started for.
///
/// Runs are serialized. A pull requested while a pull for the same account
/// is in flight shares that run's future; any other call queues one rerun
/// (its `pull` is the OR of the queued requests) and completes after it.
class SyncProgress {
  SyncProgress({
    required this._auth,
    required this._scores,
    required this._streaks,
    required this._hintQuota,
    required this._local,
    required this._remote,
    required this._leaderboard,
    required this._playPeriod,
    this._reportClientError,
    bool Function()? isRemoteAvailable,
    DateTime Function()? now,
    this.leaderboardTimeout = const Duration(seconds: 20),
    this.reportCooldown = const Duration(minutes: 10),
  }) : _isRemoteAvailable = isRemoteAvailable ?? _alwaysAvailable,
       _now = now ?? DateTime.now;

  /// Games with daily progress and a daily board.
  static const gameIds = [GameIds.zip, GameIds.pathWords, GameIds.sudoku];

  static const failureCode = 'progress_sync_failed';

  final AuthRepository _auth;
  final ScoreRepository _scores;
  final StreakRepository _streaks;
  final HintQuotaRepository _hintQuota;
  final ProgressLocalRepository _local;
  final ProgressRemoteRepository _remote;
  final LeaderboardRepository _leaderboard;
  final Duration _playPeriod;
  final ReportClientError? _reportClientError;

  /// Domain cannot see Firebase; DI passes e.g. `() => FirebaseBootstrap.isReady`.
  final bool Function() _isRemoteAvailable;
  final DateTime Function() _now;

  /// Bounds one leaderboard submit (profile read + two transactions). After a
  /// timeout the run skips its remaining submits (they retry next run).
  final Duration leaderboardTimeout;

  /// The same failure is reported at most once per this interval (runs fire
  /// on every resume and 2 s after every local change).
  final Duration reportCooldown;

  static bool _alwaysAvailable() => true;

  bool _running = false;
  bool _runningPull = false;
  String? _runningUid;
  Completer<SyncProgressResult>? _current;
  Completer<SyncProgressResult>? _rerun;
  bool _rerunPull = false;

  String? _lastReportKey;
  DateTime? _lastReportAt;

  /// [pull] fetches every remote item in scope and merges it into local.
  /// With `pull: false` (push-only, after a local change) only items whose
  /// local state differs from the last push are touched; each is still
  /// fetched and merged right before its write so a stale device never
  /// overwrites a better remote copy.
  Future<SyncProgressResult> call({bool pull = true}) {
    if (_running) {
      // An in-flight pull for this account already does all a pull asks for.
      final current = _current;
      if (pull &&
          _runningPull &&
          current != null &&
          _auth.currentUser?.uid == _runningUid) {
        return current.future;
      }
      _rerunPull = _rerunPull || pull;
      return (_rerun ??= Completer<SyncProgressResult>()).future;
    }
    _running = true;
    final completer = Completer<SyncProgressResult>();
    unawaited(_drive(completer, pull));
    return completer.future;
  }

  Future<void> _drive(Completer<SyncProgressResult> first, bool pull) async {
    var completer = first;
    var runPull = pull;
    while (true) {
      _current = completer;
      _runningPull = runPull;
      _runningUid = _auth.currentUser?.uid;
      completer.complete(await _runGuarded(runPull));
      final next = _rerun;
      if (next == null) break;
      _rerun = null;
      runPull = _rerunPull;
      _rerunPull = false;
      completer = next;
    }
    _current = null;
    _running = false;
  }

  Future<SyncProgressResult> _runGuarded(bool pull) async {
    try {
      return await _Run(this, pull).execute();
    } catch (_) {
      // [_Run] catches per item; this only guards unexpected errors.
      return const SyncProgressResult(failures: 1);
    }
  }

  /// Whether a failure with [key] is due for a report at [at] (and records
  /// it as reported).
  bool _claimReport(String key, DateTime at) {
    final last = _lastReportAt;
    if (key == _lastReportKey &&
        last != null &&
        at.difference(last) < reportCooldown) {
      return false;
    }
    _lastReportKey = key;
    _lastReportAt = at;
    return true;
  }
}

/// Thrown inside a run once the signed-in account is not the run's account.
class _AccountChanged implements Exception {
  const _AccountChanged();
}

/// State of a single sync pass.
class _Run {
  _Run(this._s, this._pull);

  final SyncProgress _s;
  bool _pull;

  bool _localChanged = false;
  int _failures = 0;
  Object? _firstError;
  StackTrace? _firstStack;
  late final DateTime _at;
  late final String _uid;

  /// The account switched mid-run; remaining items are skipped.
  bool _aborted = false;

  /// A leaderboard submit timed out (likely offline); skip the rest.
  bool _leaderboardStalled = false;

  /// Merged (or, when that failed, local) stored streak per game, for the
  /// leaderboard `currentStreak`.
  final Map<String, GameStreak> _streakByGame = {};

  Future<SyncProgressResult> execute() async {
    final user = _s._auth.currentUser;
    if (user == null || user.uid.isEmpty) return const SyncProgressResult();
    if (!_s._isRemoteAvailable()) return const SyncProgressResult();
    _uid = user.uid;
    _at = _s._now();

    if (await _attempt(_claimOwnership)) {
      final playIds = syncWindowPlayIds(_at, _s._playPeriod);
      final current = playIds.last;
      final days = <String, GameDayRecord>{};
      Future<void> syncDays(String playId) async {
        for (final gameId in SyncProgress.gameIds) {
          if (_aborted) return;
          final day = await _syncDay(gameId, playId);
          if (day != null) days['${gameId}_$playId'] = day;
        }
      }

      await syncDays(current);
      for (final gameId in SyncProgress.gameIds) {
        await _attempt(() => _syncStreak(gameId));
      }
      for (final playId in playIds) {
        if (playId != current) await syncDays(playId);
      }
      for (final gameId in SyncProgress.gameIds) {
        for (final playId in playIds) {
          final day = days['${gameId}_$playId'];
          if (day == null || _leaderboardStalled) continue;
          await _attempt(() => _syncLeaderboard(day));
        }
      }
    }

    _reportFailures();
    return SyncProgressResult(localChanged: _localChanged, failures: _failures);
  }

  /// Stops the run (see [_attempt]) once another account is signed in: its
  /// remote calls would be denied, and a leaderboard submit would land on the
  /// new account's entries.
  void _ensureSameAccount() {
    if (_s._auth.currentUser?.uid != _uid) throw const _AccountChanged();
  }

  /// Runs [step]; a throw counts as one failure, an account switch aborts the
  /// run instead. Returns whether it succeeded.
  Future<bool> _attempt(Future<void> Function() step) async {
    if (_aborted) return false;
    try {
      _ensureSameAccount();
      await step();
      return true;
    } on _AccountChanged {
      _aborted = true;
      return false;
    } catch (e, st) {
      _fail(e, st);
      return false;
    }
  }

  void _fail(Object error, StackTrace stack) {
    _failures++;
    _firstError ??= error;
    _firstStack ??= stack;
  }

  /// Legacy data (no owner yet) is claimed; another account's data is purged
  /// and this account's remote progress is pulled in its place. Progress the
  /// previous account never pushed is stashed first and comes back when that
  /// account signs in on this device again.
  Future<void> _claimOwnership() async {
    final owner = _s._local.ownerUid;
    if (owner == _uid) return;
    if (owner != null) {
      if (await _hasUnpushedProgress()) {
        await _s._local.stashUserProgress(owner);
      }
      await _s._local.purgeUserProgress();
      _localChanged = true;
      _pull = true;
    }
    await _s._local.setOwnerUid(_uid);
    if (owner != null && await _s._local.restoreStashedProgress(_uid)) {
      _localChanged = true;
    }
  }

  /// Whether a streak, window day or window leaderboard time of the current
  /// owner differs from what was last confirmed remotely.
  Future<bool> _hasUnpushedProgress() async {
    final local = _s._local;
    for (final gameId in SyncProgress.gameIds) {
      final streak = await _s._streaks.getStreak(gameId);
      final pushed = local.pushedSignature(
        ProgressLocalRepository.streakMarkerKey(gameId),
      );
      if (!_isPristineStreak(streak) && streakSignature(streak) != pushed) {
        return true;
      }
    }
    for (final playId in syncWindowPlayIds(_at, _s._playPeriod)) {
      for (final gameId in SyncProgress.gameIds) {
        final day = _localDay(gameId, playId);
        if (_isEmptyDay(day)) continue;
        final pushed = local.pushedSignature(
          ProgressLocalRepository.dayMarkerKey(gameId, playId),
        );
        if (daySignature(day) != pushed) return true;
        final time = day.timeSeconds;
        final board = local.pushedSignature(
          ProgressLocalRepository.leaderboardMarkerKey(gameId, playId),
        );
        if (time != null && time > 0 && board != '$time') return true;
      }
    }
    return false;
  }

  Future<void> _syncStreak(String gameId) async {
    final stored = await _s._streaks.getStreak(gameId);
    final todayId = StreakCalculator.dateId(_at);
    // Both copies are decayed to today first, as GetStreak shows and
    // persists them. Otherwise a stale remote copy with the same
    // lastClearedDateId but the pre-decay current wins the tie, un-decays
    // local, and Home's next GetStreak decays it again, forever.
    final local = _decayed(stored, todayId);
    _streakByGame[gameId] = local;

    final markerKey = ProgressLocalRepository.streakMarkerKey(gameId);
    final pushed = _s._local.pushedSignature(markerKey);
    if (!_pull &&
        (_isPristineStreak(local) || streakSignature(local) == pushed)) {
      return;
    }

    final remote = await _s._remote.fetchStreak(uid: _uid, gameId: gameId);
    final merged = mergeStreak(
      local,
      remote == null ? null : _decayed(remote, todayId),
    );
    final mergedSig = streakSignature(merged);
    if (mergedSig != streakSignature(stored)) {
      _ensureSameAccount();
      final wrote = await _s._streaks.restoreStreak(merged);
      // Persisting just the decay GetStreak applies anyway changes nothing
      // on screen.
      if (wrote && mergedSig != streakSignature(local)) _localChanged = true;
    }
    _streakByGame[gameId] = merged;

    if (remote == null && _isPristineStreak(merged)) return;
    // Compared with the remote copy itself, not only the marker, so a remote
    // that regressed after this device pushed mergedSig is healed.
    if (remote == null || streakSignature(remote) != mergedSig) {
      _ensureSameAccount();
      await _s._remote.saveStreak(uid: _uid, streak: merged);
    }
    if (mergedSig != pushed) {
      await _s._local.setPushedSignature(markerKey, mergedSig);
    }
  }

  static GameStreak _decayed(GameStreak streak, String todayId) =>
      StreakCalculator.applyLazyDecay(streak: streak, todayId: todayId).streak;

  /// Returns the merged day (or the local one when the remote step failed)
  /// for the leaderboard step; null when even local progress was unreadable
  /// or the run was aborted.
  Future<GameDayRecord?> _syncDay(String gameId, String playId) async {
    if (_aborted) return null;
    GameDayRecord? local;
    try {
      _ensureSameAccount();
      local = _localDay(gameId, playId);
      return await _pullPushDay(local);
    } on _AccountChanged {
      _aborted = true;
      return null;
    } catch (e, st) {
      _fail(e, st);
      return local;
    }
  }

  Future<GameDayRecord> _pullPushDay(GameDayRecord local) async {
    final markerKey = ProgressLocalRepository.dayMarkerKey(
      local.gameId,
      local.playId,
    );
    final pushed = _s._local.pushedSignature(markerKey);
    if (!_pull && (_isEmptyDay(local) || daySignature(local) == pushed)) {
      return local;
    }

    final remote = await _s._remote.fetchDay(
      uid: _uid,
      gameId: local.gameId,
      playId: local.playId,
    );
    final merged = _withLegacyFlags(mergeGameDay(local, remote));
    final mergedSig = daySignature(merged);
    if (mergedSig != daySignature(local)) await _restoreDay(merged);

    if (remote == null && _isEmptyDay(merged)) return merged;
    // Compared with the remote copy itself, not only the marker, so a remote
    // that regressed after this device pushed mergedSig (a stale write from
    // another device) is healed on the next pull.
    if (remote == null || daySignature(remote) != mergedSig) {
      final toPush = merged.cleared && merged.clearedAt == null
          ? merged.copyWith(clearedAt: _at)
          : merged;
      _ensureSameAccount();
      await _s._remote.saveDay(uid: _uid, record: toPush);
    }
    if (mergedSig != pushed) {
      await _s._local.setPushedSignature(markerKey, mergedSig);
    }
    return merged;
  }

  GameDayRecord _localDay(String gameId, String playId) {
    final modeKey = modeKeyFor(gameId, playId);
    final time = _s._scores.getBestTimeSeconds(modeKey);
    final points = _s._scores.getBestPoints(modeKey);
    final hintsUsed = _s._hintQuota.usedFor(gameId, playId);
    final record = GameDayRecord(
      gameId: gameId,
      playId: playId,
      timeSeconds: time,
      points: points > 0 ? points : null,
      hintsUsed: hintsUsed,
    );
    if (time == null) return record;

    final cleared = record.copyWith(board: _s._scores.getClearBoard(modeKey));
    final meta = _s._scores.getClearMeta(modeKey);
    if (meta != null) {
      return cleared.copyWith(
        usedHints: meta.usedHints,
        hadMistakes: meta.hadMistakes,
        flagsKnown: true,
      );
    }
    return _withLegacyFlags(cleared);
  }

  /// Cleared records without real flags get the conservative legacy guess
  /// (recomputed from the merged hint count).
  GameDayRecord _withLegacyFlags(GameDayRecord record) {
    if (!record.cleared || record.flagsKnown == true) return record;
    final flags = legacyClearFlags(record.gameId, record.hintsUsed);
    return record.copyWith(
      usedHints: flags.usedHints,
      hadMistakes: flags.hadMistakes,
      flagsKnown: false,
    );
  }

  Future<void> _restoreDay(GameDayRecord merged) async {
    _ensureSameAccount();
    final known =
        merged.flagsKnown == true &&
        merged.usedHints != null &&
        merged.hadMistakes != null;
    final scoreChanged = await _s._scores.restoreBest(
      modeKey: modeKeyFor(merged.gameId, merged.playId),
      points: merged.points,
      timeSeconds: merged.timeSeconds,
      meta: known
          ? ClearMeta(
              usedHints: merged.usedHints!,
              hadMistakes: merged.hadMistakes!,
            )
          : null,
      board: merged.board,
    );
    final hintsChanged = await _s._hintQuota.restoreUsed(
      merged.gameId,
      merged.playId,
      merged.hintsUsed,
    );
    if (scoreChanged || hintsChanged) _localChanged = true;
  }

  /// Posts a cleared day to its daily board (and all-time) once per best time.
  /// A 0 s (sub-second) clear is still a local clear but the board requires
  /// `timeSeconds > 0`, so it is never submitted.
  Future<void> _syncLeaderboard(GameDayRecord day) async {
    final time = day.timeSeconds;
    if (time == null || time <= 0) return;

    final markerKey = ProgressLocalRepository.leaderboardMarkerKey(
      day.gameId,
      day.playId,
    );
    final signature = '$time';
    if (_s._local.pushedSignature(markerKey) == signature) return;

    final legacy = legacyClearFlags(day.gameId, day.hintsUsed);
    final currentStreak = await _currentStreak(day.gameId);
    _ensureSameAccount();
    try {
      await _s._leaderboard
          .submitBestTime(
            gameId: day.gameId,
            timeSeconds: time,
            usedHints: day.usedHints ?? legacy.usedHints,
            hadMistakes: day.hadMistakes ?? legacy.hadMistakes,
            currentStreak: currentStreak,
            dayId: leaderboardDayIdForPlayId(day.playId),
            // The repository refuses the write if the account switched.
            expectedUid: _uid,
          )
          .timeout(_s.leaderboardTimeout);
    } on TimeoutException {
      _leaderboardStalled = true;
      rethrow;
    }
    await _s._local.setPushedSignature(markerKey, signature);
  }

  /// Decayed current streak, as Home / `GetStreak` show it.
  Future<int> _currentStreak(String gameId) async {
    final stored = _streakByGame[gameId] ?? await _s._streaks.getStreak(gameId);
    return _decayed(stored, StreakCalculator.dateId(_at)).current;
  }

  /// Fire-and-forget: telemetry must never hold the run (offline, a Firestore
  /// write only completes on server ack). Skipped after an account switch
  /// (the rules only accept a report under the signed-in uid).
  void _reportFailures() {
    final report = _s._reportClientError;
    if (_failures == 0 || report == null || _aborted) return;
    if (!_s._claimReport('${_firstError.runtimeType}|$_firstError', _at)) {
      return;
    }
    unawaited(
      _send(
        report,
        ClientErrorReport(
          severity: 'error',
          source: 'handled',
          code: SyncProgress.failureCode,
          message: '$_failures progress sync item(s) failed: $_firstError',
          cause: _firstError?.runtimeType.toString(),
          stack: _firstStack?.toString(),
          function: 'SyncProgress',
          uid: _uid,
        ),
      ),
    );
  }

  static Future<void> _send(
    ReportClientError report,
    ClientErrorReport error,
  ) async {
    try {
      await report(error);
    } catch (_) {
      // Best-effort telemetry.
    }
  }

  static bool _isEmptyDay(GameDayRecord day) =>
      !day.cleared && day.points == null && day.hintsUsed == 0;

  static bool _isPristineStreak(GameStreak streak) =>
      streak.current == 0 &&
      streak.longest == 0 &&
      streak.lastClearedDateId == null;
}
