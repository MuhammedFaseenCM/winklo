import 'dart:math';

/// A level's best: the most stars one run earned, and the fastest clear.
class LevelRecord {
  const LevelRecord({required this.stars, required this.bestSeconds});

  final int stars;
  final int bestSeconds;

  bool get isValid => stars >= 1 && stars <= 3 && bestSeconds >= 1;

  /// The better of both records, field by field.
  LevelRecord merge(LevelRecord other) => LevelRecord(
    stars: max(stars, other.stars),
    bestSeconds: min(bestSeconds, other.bestSeconds),
  );

  Map<String, Object> toJson() => {'stars': stars, 'bestSeconds': bestSeconds};

  /// Null for anything that isn't a valid record.
  static LevelRecord? tryParse(Object? json) {
    if (json is! Map) return null;
    final stars = json['stars'];
    final seconds = json['bestSeconds'];
    if (stars is! num || seconds is! num) return null;
    final record = LevelRecord(
      stars: stars.toInt(),
      bestSeconds: seconds.toInt(),
    );
    return record.isValid ? record : null;
  }

  @override
  bool operator ==(Object other) =>
      other is LevelRecord &&
      other.stars == stars &&
      other.bestSeconds == bestSeconds;

  @override
  int get hashCode => Object.hash(stars, bestSeconds);

  @override
  String toString() => 'LevelRecord($stars★, ${bestSeconds}s)';
}

/// One player's records in a game's Levels, by level id.
///
/// Records only ever improve, so [merge] is commutative: a phone and the
/// server can be merged in either order and agree.
class LevelProgress {
  const LevelProgress(this.records);

  static const empty = LevelProgress(<String, LevelRecord>{});

  final Map<String, LevelRecord> records;

  LevelRecord? operator [](String levelId) => records[levelId];

  bool isCleared(String levelId) => records.containsKey(levelId);

  int get totalStars => records.values.fold(0, (sum, r) => sum + r.stars);

  /// This progress after a cleared run of [levelId]. A time below 1 s (a
  /// broken clock) is kept as 1 s so the record stays valid.
  LevelProgress withRun(
    String levelId, {
    required int stars,
    required int seconds,
  }) {
    final run = LevelRecord(stars: stars, bestSeconds: max(1, seconds));
    final old = records[levelId];
    return LevelProgress({
      ...records,
      levelId: old == null ? run : old.merge(run),
    });
  }

  LevelProgress merge(LevelProgress other) {
    final merged = Map<String, LevelRecord>.of(records);
    other.records.forEach((id, record) {
      final mine = merged[id];
      merged[id] = mine == null ? record : mine.merge(record);
    });
    return LevelProgress(merged);
  }

  bool sameAs(LevelProgress other) {
    if (records.length != other.records.length) return false;
    for (final entry in records.entries) {
      if (other.records[entry.key] != entry.value) return false;
    }
    return true;
  }

  Map<String, Object> toJson() => {
    for (final entry in records.entries) entry.key: entry.value.toJson(),
  };

  /// Reads a `levels` map, dropping (and counting) entries that aren't valid
  /// records. Anything that isn't a map is empty progress.
  static ({LevelProgress progress, int dropped}) parse(Object? json) {
    if (json is! Map) return (progress: empty, dropped: 0);
    final records = <String, LevelRecord>{};
    var dropped = 0;
    json.forEach((key, value) {
      final record = LevelRecord.tryParse(value);
      if (key is String && record != null) {
        records[key] = record;
      } else {
        dropped++;
      }
    });
    return (progress: LevelProgress(records), dropped: dropped);
  }
}
