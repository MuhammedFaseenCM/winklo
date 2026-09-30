import '../repositories/notification_repository.dart';

/// Resolves a notification tap to a go_router location (default `/`).
///
/// Unknown or mistyped deep-links (e.g. `/Home`, `/word_match`) fall back to
/// home so taps never land on go_router's Page Not Found screen.
class HandleNotificationTap {
  /// Exact paths that map 1:1 to app routes.
  static const Set<String> allowedExactRoutes = {
    '/',
    '/zip',
    '/path-words',
    '/sudoku',
    '/word-match',
    '/category-race',
    '/leaderboard',
    '/profile',
    '/profile/privacy',
    '/profile/report',
  };

  /// Common admin / typo aliases → canonical app paths.
  static const Map<String, String> routeAliases = {
    '/home': '/',
    '/word_match': '/word-match',
    '/path_words': '/path-words',
    '/pathwords': '/path-words',
    '/category_race': '/category-race',
  };

  String call(NotificationTap tap) {
    final raw = tap.route.trim();
    if (raw.isEmpty) return '/';
    if (!raw.startsWith('/')) return '/';

    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasAbsolutePath) return '/';

    final path = uri.path.isEmpty ? '/' : uri.path;
    final normalizedPath = routeAliases[path.toLowerCase()] ?? path;

    if (allowedExactRoutes.contains(normalizedPath)) {
      return _withQuery(normalizedPath, uri);
    }

    // Prefixed game / profile deep-links (e.g. /word-match/deck_1).
    if (normalizedPath.startsWith('/word-match/')) {
      return _withQuery(normalizedPath, uri);
    }

    return '/';
  }

  static String _withQuery(String path, Uri uri) {
    if (uri.query.isEmpty) return path;
    return Uri(path: path, query: uri.query).toString();
  }
}
