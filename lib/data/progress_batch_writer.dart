import 'package:cloud_firestore/cloud_firestore.dart';

/// Whether [error] is the security rules refusing a write (as opposed to the
/// network or the backend failing).
bool isFirestoreRejection(Object error) =>
    error is FirebaseException && error.code == 'permission-denied';

/// Commits [records] in one batch with [commitBatch].
///
/// A batch is all-or-nothing, so when the rules reject it ([isRejection]),
/// each record is written on its own with [commitOne] and the ones the rules
/// reject again are skipped. Returns how many were skipped. Any other error,
/// from the batch or a single write, is rethrown.
Future<int> commitWithRejectionFallback<T>({
  required List<T> records,
  required Future<void> Function(List<T> records) commitBatch,
  required Future<void> Function(T record) commitOne,
  required bool Function(Object error) isRejection,
}) async {
  if (records.isEmpty) return 0;
  try {
    await commitBatch(records);
    return 0;
  } catch (e) {
    if (!isRejection(e)) rethrow;
  }
  var rejected = 0;
  for (final record in records) {
    try {
      await commitOne(record);
    } catch (e) {
      if (!isRejection(e)) rethrow;
      rejected++;
    }
  }
  return rejected;
}
