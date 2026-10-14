import '../failures.dart';

abstract class ShareRepository {
  /// Opens the system share sheet with [text]. True once the player picks an
  /// app; false when they close the sheet. Throws a [Failure] when the sheet
  /// can't open.
  Future<bool> shareText(String text);
}
