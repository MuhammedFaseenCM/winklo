import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/data/progress_batch_writer.dart';

class _Rejected implements Exception {}

void main() {
  bool isRejection(Object e) => e is _Rejected;

  test('one commit when the batch succeeds', () async {
    final batches = <List<int>>[];
    final singles = <int>[];
    final rejected = await commitWithRejectionFallback<int>(
      records: [1, 2, 3],
      commitBatch: (all) async => batches.add(all),
      commitOne: (r) async => singles.add(r),
      isRejection: isRejection,
    );
    expect(rejected, 0);
    expect(batches, [
      [1, 2, 3],
    ]);
    expect(singles, isEmpty);
  });

  test('nothing to write commits nothing', () async {
    var calls = 0;
    final rejected = await commitWithRejectionFallback<int>(
      records: const [],
      commitBatch: (_) async => calls++,
      commitOne: (_) async => calls++,
      isRejection: isRejection,
    );
    expect(rejected, 0);
    expect(calls, 0);
  });

  test('a rejected batch falls back to single writes and skips the rejected '
      'ones', () async {
    final written = <int>[];
    final rejected = await commitWithRejectionFallback<int>(
      records: [1, 2, 3, 4],
      commitBatch: (_) async => throw _Rejected(),
      commitOne: (r) async {
        if (r.isEven) throw _Rejected();
        written.add(r);
      },
      isRejection: isRejection,
    );
    expect(rejected, 2);
    expect(written, [1, 3]);
  });

  test('other batch errors are rethrown without single writes', () async {
    var singles = 0;
    await expectLater(
      commitWithRejectionFallback<int>(
        records: [1],
        commitBatch: (_) async => throw StateError('offline'),
        commitOne: (_) async => singles++,
        isRejection: isRejection,
      ),
      throwsStateError,
    );
    expect(singles, 0);
  });

  test('other single-write errors are rethrown', () async {
    await expectLater(
      commitWithRejectionFallback<int>(
        records: [1, 2],
        commitBatch: (_) async => throw _Rejected(),
        commitOne: (r) async {
          if (r == 2) throw StateError('timeout');
        },
        isRejection: isRejection,
      ),
      throwsStateError,
    );
  });

  test('permission-denied is the rules rejecting a write', () {
    expect(
      isFirestoreRejection(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
      isTrue,
    );
    expect(
      isFirestoreRejection(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      ),
      isFalse,
    );
    expect(isFirestoreRejection(StateError('x')), isFalse);
  });
}
