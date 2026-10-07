class Failure {
  const Failure(this.message, {this.cause});
  final String message;
  final Object? cause;

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
