abstract class PathWordsNounsClient {
  /// Fetches the shared daily noun list for [dateId] (`yyyyMMdd`).
  /// Throws on network/HTTP/parse failure (caller falls back).
  Future<List<String>> fetchNouns({required String dateId});
}
