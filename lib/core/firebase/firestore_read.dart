import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// How long a daily puzzle read waits for the server before using the copy
/// cached on the device.
const dailyPuzzleServerTimeout = Duration(seconds: 8);

/// Runs [fromServer], and when it hasn't answered within [timeout], returns
/// [fromCache] instead (which throws when nothing is cached).
///
/// Other server errors are rethrown: only slowness falls back.
Future<T> readPreferringServer<T>({
  required Future<T> Function() fromServer,
  required Future<T> Function() fromCache,
  Duration timeout = dailyPuzzleServerTimeout,
}) async {
  try {
    return await fromServer().timeout(timeout);
  } on TimeoutException {
    return fromCache();
  }
}

/// Reads [ref] from the server, falling back to the device cache when the
/// server is slow.
///
/// `Source.serverAndCache` only serves the cache once the SDK decides it is
/// offline, which can take longer than a player will wait, so a slow
/// connection would otherwise fail even with the puzzle already cached.
Future<DocumentSnapshot<Map<String, dynamic>>> getDocPreferringServer(
  DocumentReference<Map<String, dynamic>> ref, {
  Duration timeout = dailyPuzzleServerTimeout,
}) {
  return readPreferringServer(
    fromServer: () => ref.get(const GetOptions(source: Source.serverAndCache)),
    fromCache: () => ref.get(const GetOptions(source: Source.cache)),
    timeout: timeout,
  );
}
