import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/domain/repositories/daily_puzzle_prefetch_repository.dart';

/// Reads a day's daily docs from the server; Firestore keeps what it reads
/// in its device cache, which the games fall back to when offline.
class DailyPuzzlePrefetchRepositoryImpl
    implements DailyPuzzlePrefetchRepository {
  DailyPuzzlePrefetchRepositoryImpl({FirebaseFirestore? firestore})
    : _read = _serverReader(
        firestore ??
            (FirebaseBootstrap.isReady ? FirebaseFirestore.instance : null),
      );

  /// For tests: [read] gets each doc path, such as `zip_levels/daily_…`.
  DailyPuzzlePrefetchRepositoryImpl.withReader(
    Future<void> Function(String path) read,
  ) : _read = read;

  /// The collections the three dailies are read from.
  static const collections = [
    'zip_levels',
    'path_words_levels',
    'sudoku_levels',
  ];

  final Future<void> Function(String path)? _read;

  static Future<void> Function(String path)? _serverReader(
    FirebaseFirestore? firestore,
  ) {
    if (firestore == null) return null;
    return (path) =>
        firestore.doc(path).get(const GetOptions(source: Source.server));
  }

  @override
  Future<void> prefetch(String dateId) async {
    final read = _read;
    if (read == null) return;
    await Future.wait([
      for (final collection in collections)
        _quietly(() => read('$collection/daily_$dateId')),
    ]);
  }

  /// Not live yet (permission-denied), offline, or missing: all the same to
  /// a cache warm-up.
  static Future<void> _quietly(Future<void> Function() read) async {
    try {
      await read();
    } catch (_) {}
  }
}
