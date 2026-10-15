/// Posts cleared runs to the leaderboard Worker (`POST /v1/submit`).
abstract class LeaderboardSubmitClient {
  /// Sends one submit [body] for the user behind [idToken].
  ///
  /// Throws [LeaderboardSubmitRejected] when the Worker refuses the clear (a
  /// 4xx: final, don't retry) and [LeaderboardSubmitUnavailable] on a network
  /// error, a timeout or a 5xx (the caller may write another way).
  Future<LeaderboardSubmitResult> submit({
    required String idToken,
    required Map<String, Object?> body,
  });
}

class LeaderboardSubmitResult {
  const LeaderboardSubmitResult({required this.improved});

  /// Whether the daily board's time got better.
  final bool improved;
}

/// The Worker checked the clear and refused it.
class LeaderboardSubmitRejected implements Exception {
  const LeaderboardSubmitRejected(this.statusCode, this.code);

  final int statusCode;

  /// `bad_request`, `not_live`, `too_fast`, `bad_proof`, `unknown_puzzle` or
  /// `unauthorized` (a 401).
  final String code;

  @override
  String toString() => 'LeaderboardSubmitRejected($statusCode, $code)';
}

/// The Worker couldn't be reached or failed; nothing was decided.
class LeaderboardSubmitUnavailable implements Exception {
  const LeaderboardSubmitUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'LeaderboardSubmitUnavailable($reason)';
}
