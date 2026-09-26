abstract final class AvatarUploadConfig {
  /// Production Worker URL. Override with
  /// `--dart-define=AVATAR_UPLOAD_BASE_URL=…` for staging/local Workers.
  static const String baseUrl = String.fromEnvironment(
    'AVATAR_UPLOAD_BASE_URL',
    defaultValue: 'https://winklo-avatar-upload.winklo.workers.dev',
  );

  static bool get isConfigured => baseUrl.trim().isNotEmpty;
}
