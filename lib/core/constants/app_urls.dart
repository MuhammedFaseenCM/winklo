import '../../domain/game_ids.dart';

abstract final class AppUrls {
  static const landing = 'https://winklo.pages.dev';

  static const privacyPolicy = 'https://winklo.pages.dev/privacy/';

  /// Web page that deletes the account (needs Google sign-in in a browser).
  static const accountDeletion = 'https://winklo.pages.dev/delete-account/';

  /// The App Link that opens [gameId] in the app, or its page on the site
  /// for people without the app (`https://winklo.pages.dev/zip`).
  static String game(String gameId) => switch (gameId) {
    GameIds.pathWords => '$landing/path-words',
    GameIds.sudoku => '$landing/sudoku',
    _ => '$landing/zip',
  };
}
