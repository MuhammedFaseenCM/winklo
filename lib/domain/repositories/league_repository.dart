import '../entities/league.dart';
import '../failures.dart';

enum LeagueProblem {
  /// No league has this code (or it was deleted).
  notFound,

  /// The league already has 30 players.
  full,

  /// Signed out, or the account changed.
  signedOut,
}

class LeagueFailure extends Failure {
  const LeagueFailure(this.problem, super.message, {super.cause});

  final LeagueProblem problem;
}

abstract class LeagueRepository {
  /// The leagues [uid] belongs to, by name.
  Stream<List<League>> watchMyLeagues(String uid);

  /// One league, live; null once it's deleted (or can't be read).
  Stream<League?> watchLeague(String leagueId);

  /// The league behind [code], or null when there is none.
  Future<League?> findByCode(String code);

  /// Creates a league named [name] with the signed-in player as its owner and
  /// only member, under a fresh code.
  Future<League> create(String name);

  /// Adds the signed-in player to the league behind [code]. Joining a league
  /// you're already in just returns it. Throws a [LeagueFailure].
  Future<League> join(String code);

  /// Removes the signed-in player (not the owner) from [leagueId].
  Future<void> leave(String leagueId);

  /// Owner only: removes [memberUid] from [leagueId].
  Future<void> removeMember(String leagueId, String memberUid);

  /// Owner only.
  Future<void> rename(String leagueId, String name);

  /// Owner only: deletes the league and its code.
  Future<void> delete(League league);

  /// Public names and photos of [uids], from their leaderboard entries.
  /// Players with no entry yet are missing from the map.
  Future<Map<String, LeagueMember>> memberProfiles(List<String> uids);
}
