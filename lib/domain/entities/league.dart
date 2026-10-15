import '../league_code.dart';

/// A private league: a board of up to 30 players who joined with its code.
///
/// Mirrors `leagues/{leagueId}`; `league_codes/{code}` points back to it.
class League {
  const League({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.code,
    required this.memberUids,
    this.createdAt,
  });

  final String id;
  final String name;
  final String ownerUid;
  final String code;
  final List<String> memberUids;
  final DateTime? createdAt;

  bool isOwner(String? uid) => uid != null && uid == ownerUid;

  bool hasMember(String? uid) => uid != null && memberUids.contains(uid);

  bool get isFull => memberUids.length >= leaguesMaxMembers;

  String get inviteUrl => leagueInviteUrl(code);
}

/// A league member's public name and photo, from their leaderboard entries.
class LeagueMember {
  const LeagueMember({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.avatarId,
  });

  final String uid;
  final String displayName;
  final String? photoUrl;
  final String? avatarId;
}
