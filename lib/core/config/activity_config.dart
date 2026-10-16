abstract final class ActivityConfig {
  /// The activity Worker (`workers/activity`), which records guests' app
  /// opens. Override with `--dart-define=ACTIVITY_BASE_URL=…` for staging or
  /// a local Worker; an empty value leaves guest opens unrecorded.
  static const String baseUrl = String.fromEnvironment(
    'ACTIVITY_BASE_URL',
    defaultValue: 'https://winklo-activity.winklo.workers.dev',
  );

  static bool get isConfigured => baseUrl.trim().isNotEmpty;
}
