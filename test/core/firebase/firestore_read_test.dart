import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/firebase/firestore_read.dart';

void main() {
  const short = Duration(milliseconds: 20);

  test('uses the server when it answers in time', () async {
    final result = await readPreferringServer(
      fromServer: () async => 'server',
      fromCache: () async => 'cache',
      timeout: short,
    );
    expect(result, 'server');
  });

  test('falls back to the cache when the server is slow', () async {
    final result = await readPreferringServer(
      fromServer: () => Completer<String>().future,
      fromCache: () async => 'cache',
      timeout: short,
    );
    expect(result, 'cache');
  });

  test('fails when the server is slow and nothing is cached', () async {
    expect(
      readPreferringServer<String>(
        fromServer: () => Completer<String>().future,
        fromCache: () => Future.error(StateError('not cached')),
        timeout: short,
      ),
      throwsStateError,
    );
  });

  test('a server error is not hidden behind the cache', () async {
    var cacheRead = false;
    await expectLater(
      readPreferringServer<String>(
        fromServer: () => Future.error(ArgumentError('permission denied')),
        fromCache: () async {
          cacheRead = true;
          return 'cache';
        },
        timeout: short,
      ),
      throwsArgumentError,
    );
    expect(cacheRead, isFalse);
  });
}
