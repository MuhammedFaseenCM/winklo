/// Posts a guest's (signed-out) app open to the activity Worker
/// (`workers/activity`, `POST /v1/open`).
abstract class GuestActivityClient {
  /// Sends one open [body]. Throws [GuestActivityUnavailable] when the Worker
  /// didn't record it: a network error, a timeout, a refusal or a 5xx.
  Future<void> recordOpen(Map<String, Object?> body);
}

/// The Worker didn't record the open; the next open tries again.
class GuestActivityUnavailable implements Exception {
  const GuestActivityUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'GuestActivityUnavailable($reason)';
}
