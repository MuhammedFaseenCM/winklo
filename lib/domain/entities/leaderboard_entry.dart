class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.timeSeconds,
    required this.updatedAt,
    required this.rank,
    this.photoUrl,
    this.avatarId,
  });

  final String uid;
  final String displayName;
  final String? photoUrl;
  final String? avatarId;
  final int timeSeconds;
  final DateTime updatedAt;
  final int rank;
}
