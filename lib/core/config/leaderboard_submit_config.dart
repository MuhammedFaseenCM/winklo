abstract final class LeaderboardSubmitConfig {
  /// The leaderboard Worker (`workers/leaderboard`). Override with
  /// `--dart-define=LEADERBOARD_SUBMIT_BASE_URL=…` for staging or local
  /// Workers; an empty value makes the app write the boards directly.
  static const String baseUrl = String.fromEnvironment(
    'LEADERBOARD_SUBMIT_BASE_URL',
    defaultValue: 'https://winklo-leaderboard.winklo.workers.dev',
  );

  static bool get isConfigured => baseUrl.trim().isNotEmpty;
}
