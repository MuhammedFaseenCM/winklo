import '../game_ids.dart';
import 'leaderboard_proof.dart';

/// A level clear the Worker hasn't taken yet, kept until it is sent.
class PendingLevelClear {
  const PendingLevelClear({
    required this.levelId,
    required this.stars,
    required this.timeSeconds,
    required this.usedHints,
    required this.proof,
  });

  final String levelId;

  /// The app's own local star count; only used to choose which run to keep.
  final int stars;
  final int timeSeconds;
  final bool usedHints;
  final ZipLeaderboardProof proof;

  /// More stars wins, then a lower time. An equal clear is not better.
  bool betterThan(PendingLevelClear other) {
    if (stars != other.stars) return stars > other.stars;
    return timeSeconds < other.timeSeconds;
  }

  Map<String, Object?> toJson() => {
    'levelId': levelId,
    'stars': stars,
    'timeSeconds': timeSeconds,
    'usedHints': usedHints,
    'proof': proof.toJson(),
  };

  /// Null when [json] isn't a saved clear.
  static PendingLevelClear? fromJson(Object? json) {
    if (json is! Map) return null;
    final levelId = json['levelId'];
    final stars = json['stars'];
    final time = json['timeSeconds'];
    final hints = json['usedHints'];
    final proof = LeaderboardProof.fromJson(GameIds.zip, json['proof']);
    if (levelId is! String ||
        stars is! int ||
        time is! int ||
        hints is! bool ||
        proof is! ZipLeaderboardProof) {
      return null;
    }
    return PendingLevelClear(
      levelId: levelId,
      stars: stars,
      timeSeconds: time,
      usedHints: hints,
      proof: proof,
    );
  }
}
