import 'dart:async';

import '../entities/client_error_report.dart';
import '../entities/leaderboard_proof.dart';
import '../entities/pending_level_clear.dart';
import '../failures.dart';
import '../repositories/analytics_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/leaderboard_repository.dart';
import '../repositories/pending_level_clear_repository.dart';
import 'report_client_error.dart';

/// Sends a level clear to the Levels board through the leaderboard Worker.
///
/// A clear is kept per account first and dropped once the Worker has
/// answered for good (taken it or refused it), so one that couldn't be sent
/// is still there for [resendPending]. Never throws.
///
/// One instance is shared by every caller (the Zip bloc and the sync): its
/// reads and writes of the pending store are queued one after another,
/// because the store reads, changes and rewrites its list and two overlapping
/// calls would lose an update. The network sends are not queued.
class SubmitLevelClear {
  SubmitLevelClear({
    required this._auth,
    required this._leaderboard,
    required this._pending,
    required this._analytics,
    this._reportClientError,
  });

  static const failureCode = 'level_board_submit_failed';

  final AuthRepository _auth;
  final LeaderboardRepository _leaderboard;
  final PendingLevelClearRepository _pending;
  final AnalyticsRepository _analytics;
  final ReportClientError? _reportClientError;

  Future<void> _tail = Future<void>.value();
  Future<void>? _resending;
  final _accepted = StreamController<String>.broadcast();

  /// The level id of each clear the Worker took (from [call] and
  /// [resendPending]), while the account that sent it is still signed in:
  /// the board now holds that level.
  Stream<String> get accepted => _accepted.stream;

  /// Runs [op] after every earlier store operation has finished, whether it
  /// succeeded or not.
  Future<T> _serial<T>(Future<T> Function() op) {
    final result = _tail.then((_) => op());
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  /// [improved] is whether this run set the level's record; it is only
  /// reported to analytics.
  Future<void> call({
    required String game,
    required String levelId,
    required int stars,
    required int timeSeconds,
    required bool usedHints,
    required ZipLeaderboardProof proof,
    bool improved = false,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.uid.isEmpty) return;
      final clear = PendingLevelClear(
        levelId: levelId,
        stars: stars,
        timeSeconds: timeSeconds,
        usedHints: usedHints,
        proof: proof,
      );
      await _serial(() => _pending.keep(user.uid, game, clear));
      await _send(user.uid, game, clear, improved: improved);
    } catch (error, stack) {
      _report(_auth.currentUser?.uid, error, stack);
    }
  }

  /// Sends the current account's unsent clears of [game], one at a time. It
  /// stops when another account signs in (the rest belong to the first
  /// account and the write would land on the wrong one) and at the first
  /// clear the Worker can't be reached for (the rest would fail too).
  ///
  /// One resend runs at a time: a call made while one is running (a timed-out
  /// sync pass leaves its loop going) gets that run's future instead of
  /// starting a second loop that would post the same clears again.
  Future<void> resendPending(String game) {
    final running = _resending;
    if (running != null) return running;
    final run = _resend(game).whenComplete(() => _resending = null);
    return _resending = run;
  }

  Future<void> _resend(String game) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null || uid.isEmpty) return;
      final clears = await _serial(() async => _pending.pending(uid, game));
      for (final clear in clears) {
        if (_auth.currentUser?.uid != uid) return;
        final outcome = await _send(uid, game, clear);
        if (outcome == LevelClearSubmitOutcome.unavailable) return;
      }
    } catch (error, stack) {
      _report(_auth.currentUser?.uid, error, stack);
    }
  }

  /// Posts [clear] and settles it. Null when it couldn't be settled (an
  /// unexpected error, reported; the clear stays pending).
  Future<LevelClearSubmitOutcome?> _send(
    String uid,
    String game,
    PendingLevelClear clear, {
    bool improved = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != uid) return null;
    try {
      final outcome = await _leaderboard.submitLevelClear(
        gameId: game,
        levelId: clear.levelId,
        timeSeconds: clear.timeSeconds,
        usedHints: clear.usedHints,
        proof: clear.proof,
        expectedUid: uid,
      );
      switch (outcome) {
        case LevelClearSubmitOutcome.sent:
          if (_auth.currentUser?.uid == uid && !_accepted.isClosed) {
            _accepted.add(clear.levelId);
          }
          await _settled(uid, game, clear);
          await _log(clear, accepted: true, improved: improved);
        case LevelClearSubmitOutcome.unavailable:
          await _log(
            clear,
            accepted: false,
            improved: improved,
            code: 'unavailable',
          );
        case LevelClearSubmitOutcome.notSent:
          // A build that doesn't send: nothing should pile up.
          await _settled(uid, game, clear);
          await _log(
            clear,
            accepted: false,
            improved: improved,
            code: 'not_sent',
          );
      }
      return outcome;
    } on LeaderboardSubmitRefused catch (refused, stack) {
      // Final: the same clear is refused every time.
      await _settled(uid, game, clear);
      await _log(
        clear,
        accepted: false,
        improved: improved,
        code: refused.code,
      );
      _report(uid, refused, stack);
      return null;
    } catch (error, stack) {
      _report(uid, error, stack);
      return null;
    }
  }

  Future<void> dispose() => _accepted.close();

  /// Drops [clear] unless a better run of the level was kept while it was
  /// being sent: that one is still waiting.
  Future<void> _settled(String uid, String game, PendingLevelClear clear) {
    return _serial(() async {
      final current = _pending
          .pending(uid, game)
          .where((c) => c.levelId == clear.levelId)
          .firstOrNull;
      if (current == null || current.betterThan(clear)) return;
      await _pending.drop(uid, game, clear.levelId);
    });
  }

  Future<void> _log(
    PendingLevelClear clear, {
    required bool accepted,
    required bool improved,
    String? code,
  }) async {
    try {
      await _analytics.logLevelBoardSubmit(
        levelId: clear.levelId,
        accepted: accepted,
        improved: improved,
        code: code,
      );
    } catch (_) {
      // Telemetry never holds up the clear.
    }
  }

  /// Fire-and-forget; skipped when the account changed (the rules only take
  /// a report under the signed-in uid).
  void _report(String? uid, Object error, StackTrace stack) {
    final report = _reportClientError;
    if (report == null || uid == null || _auth.currentUser?.uid != uid) return;
    if (error is TimeoutException) return;
    if (error is Failure && !error.reportable) return;
    unawaited(_sendReport(report, uid, error, stack));
  }

  static Future<void> _sendReport(
    ReportClientError report,
    String uid,
    Object error,
    StackTrace stack,
  ) async {
    try {
      await report(
        ClientErrorReport(
          severity: 'error',
          source: 'handled',
          code: failureCode,
          message: 'Level clear was not sent to the board: $error',
          cause: error.toString(),
          stack: stack.toString(),
          function: 'SubmitLevelClear',
          uid: uid,
        ),
      );
    } catch (_) {
      // Best-effort telemetry.
    }
  }
}
