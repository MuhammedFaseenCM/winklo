import 'dart:async';

import '../entities/client_error_report.dart';
import '../failures.dart';
import '../repositories/auth_repository.dart';
import '../repositories/level_play_stats_repository.dart';
import 'report_client_error.dart';

/// Counts a level start, clear or hint for the admin's Levels views.
///
/// Never throws: play must not wait on or fail because of a counter. Signed
/// out, or before Firebase is ready, nothing is recorded. A failure is
/// reported at most once per [reportCooldown] for the same error; timeouts
/// (offline) are not reported, since Firestore keeps the write queued.
class RecordLevelPlay {
  RecordLevelPlay({
    required this._auth,
    required this._stats,
    this._reportClientError,
    bool Function()? isRemoteAvailable,
    DateTime Function()? now,
    this.reportCooldown = const Duration(minutes: 10),
  }) : _isRemoteAvailable = isRemoteAvailable ?? _always,
       _now = now ?? DateTime.now;

  static const failureCode = 'level_stats_write_failed';

  final AuthRepository _auth;
  final LevelPlayStatsRepository _stats;
  final ReportClientError? _reportClientError;
  final bool Function() _isRemoteAvailable;
  final DateTime Function() _now;

  /// The same failure is reported at most once per this interval.
  final Duration reportCooldown;

  String? _lastReportKey;
  DateTime? _lastReportAt;

  static bool _always() => true;

  Future<void> call({
    required String game,
    required String levelId,
    required LevelPlayEvent event,
  }) async {
    String? uid;
    try {
      uid = _auth.currentUser?.uid;
      if (uid == null || !_isRemoteAvailable()) return;
      await _stats.increment(uid, game, levelId, event);
    } catch (error, stack) {
      if (uid != null) _report(uid, error, stack);
    }
  }

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
          message: 'Level stats write failed: $error',
          cause: error.toString(),
          stack: stack.toString(),
          function: 'RecordLevelPlay',
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
