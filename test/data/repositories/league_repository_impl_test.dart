import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/data/repositories/league_repository_impl.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/repositories/league_repository.dart';

void main() {
  group('leagueFromDoc', () {
    test('reads a league doc', () {
      final league = leagueFromDoc('L1', {
        'name': 'Family',
        'ownerUid': 'u1',
        'code': 'ABC234',
        'memberUids': ['u1', 'u2', 7],
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 15)),
      })!;
      expect(league.id, 'L1');
      expect(league.memberUids, ['u1', 'u2']);
      expect(league.isOwner('u1'), isTrue);
      expect(league.hasMember('u2'), isTrue);
      expect(league.isFull, isFalse);
      expect(league.inviteUrl, 'https://winklo.pages.dev/join/ABC234');
      expect(league.createdAt?.toUtc(), DateTime.utc(2026, 10, 15));
    });

    test('refuses a malformed doc', () {
      expect(leagueFromDoc('L1', null), isNull);
      expect(leagueFromDoc('L1', {'name': 'x', 'ownerUid': 'u1'}), isNull);
    });
  });

  test('a new league has its owner as the only member', () {
    final data = newLeagueData(name: 'Family', ownerUid: 'u1', code: 'ABC234');
    expect(data.keys.toSet(), leagueFirestoreKeys);
    expect(data['memberUids'], ['u1']);
    expect(data['createdAt'], isA<FieldValue>());
  });

  group('LeagueRepositoryImpl', () {
    test('needs Firebase and a signed-in player', () async {
      final wasReady = FirebaseBootstrap.isReady;
      addTearDown(() => FirebaseBootstrap.isReady = wasReady);
      FirebaseBootstrap.isReady = false;
      final repo = LeagueRepositoryImpl();
      await expectLater(
        repo.create('Family'),
        throwsA(
          isA<LeagueFailure>().having(
            (f) => f.problem,
            'problem',
            LeagueProblem.signedOut,
          ),
        ),
      );
      expect(repo.watchMyLeagues('u1'), emitsError(isA<Failure>()));
      expect(await repo.memberProfiles(const ['u1']), isEmpty);
    });

    test('refuses a blank or long name before any I/O', () async {
      final repo = LeagueRepositoryImpl();
      for (final name in ['  ', 'x' * 31]) {
        await expectLater(repo.create(name), throwsA(isA<Failure>()));
        await expectLater(repo.rename('L1', name), throwsA(isA<Failure>()));
      }
    });

    test('an impossible code finds nothing', () async {
      expect(await LeagueRepositoryImpl().findByCode('nope'), isNull);
    });
  });
}
