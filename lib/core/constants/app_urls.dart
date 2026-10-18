import '../../domain/game_ids.dart';

abstract final class AppUrls {
  /// Marketing landing (Cloudflare Pages).
  static const landing = 'https://winklo.pages.dev';

  /// Verified App Links host (Firebase Hosting — free, Google can crawl it).
  static const appLinks = 'https://brain-zip-app.web.app';

  static const privacyPolicy = '$landing/privacy/';

  /// Web page that deletes the account (needs Google sign-in in a browser).
  static const accountDeletion = '$landing/delete-account/';

  /// The App Link that opens [gameId] in the app, or its page on the site
  /// for people without the app (`https://brain-zip-app.web.app/zip`).
  static String game(String gameId) => switch (gameId) {
    GameIds.pathWords => '$appLinks/path-words',
    GameIds.sudoku => '$appLinks/sudoku',
    _ => '$appLinks/zip',
  };
}
