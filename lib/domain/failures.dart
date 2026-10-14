class Failure {
  const Failure(this.message, {this.cause, this.reportable = true});
  final String message;
  final Object? cause;

  /// When false, sync/telemetry may retry but should not open a client_errors
  /// ticket (expected transient conditions such as unacked offline writes).
  final bool reportable;

  @override
  String toString() => 'Failure($message)';
}

/// Thrown when a daily puzzle cannot be loaded from the backend.
class DailyPuzzleUnavailable implements Exception {
  const DailyPuzzleUnavailable([this.message = 'Daily puzzle unavailable']);
  final String message;

  @override
  String toString() => message;
}

/// Thrown when a daily puzzle loads but this build can't play its shape,
/// for example a 9×9 Sudoku. Players need a newer app, not a retry.
class UnsupportedPuzzle extends DailyPuzzleUnavailable {
  const UnsupportedPuzzle([super.message = 'Unsupported puzzle shape']);
}
