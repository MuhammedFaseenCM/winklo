abstract final class StaticAssetsConfig {
  /// Public R2 base URL (no trailing slash). Override with
  /// `--dart-define=STATIC_ASSETS_BASE_URL=…` for staging.
  static const String baseUrl = String.fromEnvironment(
    'STATIC_ASSETS_BASE_URL',
    defaultValue: 'https://pub-94fd8286c7fa4508a0e988821039d2a8.r2.dev',
  );

  /// Builds a public URL under `static/` on the assets bucket.
  ///
  /// [relativePath] is like `games/zip_tile.png` (no leading slash).
  static String url(String relativePath) {
    final base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final path = relativePath.replaceFirst(RegExp(r'^/+'), '');
    return '$base/static/$path';
  }
}
