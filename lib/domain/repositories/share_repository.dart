abstract class ShareRepository {
  /// Opens the system share sheet with [text]. True when it was shared, or
  /// when the platform can't say; false when the player closed the sheet.
  Future<bool> shareText(String text);
}
