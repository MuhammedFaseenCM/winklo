import 'dart:async';

import '../entities/client_error_report.dart';
import '../entities/level_progress.dart';
import '../failures.dart';
import '../game_ids.dart';
import '../repositories/auth_repository.dart';
import '../repositories/level_progress_remote_repository.dart';
import '../repositories/level_progress_repository.dart';
import 'report_client_error.dart';

/// Reconciles this device's level progress with the account's copy.
///
/// Per game: read the remote doc, merge (most stars, fastest time), keep the
/// result locally, and write it back only when the remote copy differs. A
/// push-only run ([pull] false) skips games with nothing new to push. The
/// merge can't conflict; two devices converge on each one's next full sync (a
/// write from another device between this run's fetch and save is picked up
/// then).
///
/// Runs never overlap: a call during a run queues one rerun whose `pull` is
/// the OR of the queued requests. A failure is reported (rate-limited) and
/// rethrown so the caller can log it and retry on its next run.
class SyncLevelProgress {
  SyncLevelProgress({
    required this._auth,
    required this._local,
    required this._remote,
    this._reportClientError,
    bool Function()? isRemoteAvailable,
    DateTime Function()? now,
    this.reportCooldown = const Duration(minutes: 10),
  }) : _isRemoteAvailable = isRemoteAvailable ?? _always,
       _now = now ?? DateTime.now;

  /// Games with Levels.
  static const gameIds = [GameIds.zip];

  static const failureCode = 'level_progress_sync_failed';

  final AuthRepository _auth;
  final LevelProgressRepository _local;
  final LevelProgressRemoteRepository _remote;
  final ReportClientError? _reportClientError;
  final bool Function() _isRemoteAvailable;
  final DateTime Function() _now;

  /// The same failure is reported at most once per this interval.
  final Duration reportCooldown;

  static bool _always() => true;

  bool _running = false;
  bool _runningPull = false;
  String? _runningUid;
  Completer<void>? _current;
  Completer<void>? _rerun;
  bool _rerunPull = false;
  String? _lastReportKey;
  DateTime? _lastReportAt;

  Future<void> call({required bool pull}) {
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
      return (_rerun ??= Completer<void>()).future;
    }
    _running = true;
    final completer = Completer<void>();
    unawaited(_drive(completer, pull));
    return completer.future;
  }

  Future<void> _drive(Completer<void> first, bool pull) async {
    var completer = first;
    var runPull = pull;
    try {
      while (true) {
        _current = completer;
        _runningPull = runPull;
        try {
          _runningUid = _auth.currentUser?.uid;
          await _run(pull: runPull);
          completer.complete();
        } catch (e, s) {
          completer.completeError(e, s);
        }
        final next = _rerun;
        if (next == null) break;
        _rerun = null;
        runPull = _rerunPull;
        _rerunPull = false;
        completer = next;
      }
    } finally {
      _current = null;
      _running = false;
    }
  }

  Future<void> _run({required bool pull}) async {
    if (!_isRemoteAvailable()) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    for (final game in gameIds) {
      try {
        if (!await _syncGame(uid, game, pull: pull)) return;
      } catch (error, stack) {
        _report(uid, error, stack);
        rethrow;
      }
    }
  }

  /// Returns false when the account changed and the run should stop.
  Future<bool> _syncGame(String uid, String game, {required bool pull}) async {
    if (!pull && !_local.needsPush(game)) return true;
    final remote = LevelProgress.parse(await _remote.fetch(uid, game));
    // Another account signed in while we read: leave both copies alone.
    if (_auth.currentUser?.uid != uid) return false;
    final local = _local.progress(game);
    final merged = local.merge(remote.progress);
    if (!merged.sameAs(local)) await _local.restore(game, merged);
    if (!merged.sameAs(remote.progress) || remote.dropped > 0) {
      await _remote.save(uid, game, merged);
    }
    // The local store is keyed by whoever is signed in now.
    if (_auth.currentUser?.uid != uid) return false;
    await _local.markPushed(game, merged);
    return true;
  }

  /// Fire-and-forget; skipped after an account switch (the rules only accept
  /// a report under the signed-in uid) and for expected transient failures.
  void _report(String uid, Object error, StackTrace stack) {
    final report = _reportClientError;
    if (report == null || _auth.currentUser?.uid != uid) return;
    if (error is TimeoutException) return;
    if (error is Failure && !error.reportable) return;
    final at = _now();
    final key = '${error.runtimeType}|$error';
    final last = _lastReportAt;
    if (key == _lastReportKey &&
        last != null &&
        at.difference(last) < reportCooldown) {
      return;
    }
    _lastReportKey = key;
    _lastReportAt = at;
    unawaited(
      _send(
        report,
        ClientErrorReport(
          severity: 'error',
          source: 'handled',
          code: failureCode,
          message: 'Level progress sync failed: $error',
          cause: error.toString(),
          stack: stack.toString(),
          function: 'SyncLevelProgress',
          uid: uid,
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
}
