abstract final class PathWordsNounsConfig {
  /// Production Worker URL. Override with
  /// `--dart-define=PATH_WORDS_NOUNS_BASE_URL=…` for staging/local.
  static const String baseUrl = String.fromEnvironment(
    'PATH_WORDS_NOUNS_BASE_URL',
    defaultValue: 'https://winklo-path-words-nouns.winklo.workers.dev',
  );

  static bool get isConfigured => baseUrl.trim().isNotEmpty;
}
