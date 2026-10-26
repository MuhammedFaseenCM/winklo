import '../app_calendar.dart';

/// Picks which line of a pool a notification uses, so the words change from
/// one notification to the next without storing what was shown.
///
/// Turns walk through passes of `size` turns: each pass uses every line once,
/// in an order seeded by the key and the pass, and a pass never starts with
/// the line the previous one ended on. The same algorithm runs in
/// winklo-admin's Worker (`workers/admin-api/src/shuffle_bag.ts`, on
/// `seeded_random.ts`), so both pick the same line for the same key and turn.
abstract final class ShuffleBag {
  static const _mask = 0xFFFFFFFF;

  /// The line, in `[0, size)`, for [turn] of the pool named [key].
  static int pick(String key, int turn, int size) {
    if (size <= 1) return 0;
    if (size == 2) return (turn + (fnv1a(key) & 1)) % 2;
    final pass = turn ~/ size;
    final order = _order(key, pass, size);
    if (pass > 0) {
      final previousLast = _order(key, pass - 1, size)[size - 1];
      if (order[0] == previousLast) {
        order[0] = order[1];
        order[1] = previousLast;
      }
    }
    return order[turn % size];
  }

  /// [instant]'s local calendar day, counted from 1 January 1970: the turn of
  /// a pool that changes once a day.
  static int epochDay(DateTime instant) {
    final local = AppCalendar.localWallClock(instant);
    return DateTime.utc(
          local.year,
          local.month,
          local.day,
        ).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
  }

  /// Fisher–Yates over `[0, size)`, as the Worker's `shuffleInPlace`.
  static List<int> _order(String key, int pass, int size) {
    final next = mulberry32(fnv1a('$key#$pass'));
    final order = List<int>.generate(size, (i) => i);
    for (var i = size - 1; i > 0; i--) {
      final j = (next() * (i + 1)).floor();
      final swap = order[i];
      order[i] = order[j];
      order[j] = swap;
    }
    return order;
  }

  /// FNV-1a over UTF-16 code units, as the Worker's `seedFromString`.
  static int fnv1a(String text) {
    var hash = 2166136261;
    for (final unit in text.codeUnits) {
      hash = _imul(hash ^ unit, 16777619);
    }
    return hash;
  }

  /// Mulberry32, as the Worker's: numbers in `[0, 1)`. JavaScript's 32-bit
  /// integer maths is kept by masking every step to 32 bits.
  static double Function() mulberry32(int seed) {
    var t = seed & _mask;
    return () {
      t = (t + 0x6d2b79f5) & _mask;
      var r = _imul(t ^ (t >>> 15), 1 | t);
      r ^= (r + _imul(r ^ (r >>> 7), 61 | r)) & _mask;
      return ((r ^ (r >>> 14)) & _mask) / 4294967296;
    };
  }

  /// `Math.imul`, as an unsigned 32-bit result.
  static int _imul(int a, int b) => (a * b) & _mask;
}
