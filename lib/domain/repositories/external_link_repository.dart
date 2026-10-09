/// Opens links outside the app, in the system browser.
abstract class ExternalLinkRepository {
  /// Whether [uri] opened.
  Future<bool> open(Uri uri);
}
