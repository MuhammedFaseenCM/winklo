import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/league.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/league_repository.dart';
import 'package:winklo/features/leagues/cubit/join_league_cubit.dart';
import 'package:winklo/features/leagues/cubit/league_detail_cubit.dart';
import 'package:winklo/features/leagues/cubit/leagues_cubit.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockLeagues extends Mock implements LeagueRepository {}

const _me = AppUser(uid: 'u1', displayName: 'Ada');

const _family = League(
  id: 'L1',
  name: 'Family',
  ownerUid: 'u1',
  code: 'ABC234',
  memberUids: ['u1', 'u2'],
);

const _theirs = League(
  id: 'L2',
  name: 'Office',
  ownerUid: 'u9',
  code: 'XYZ234',
  memberUids: ['u9'],
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _MockAuth auth;
  late _MockLeagues leagues;

  setUpAll(() {
    registerFallbackValue(_family);
  });

  setUp(() {
    auth = _MockAuth();
    leagues = _MockLeagues();
    when(() => auth.currentUser).thenReturn(_me);
    when(() => auth.authStateChanges()).thenAnswer((_) => const Stream.empty());
  });

  group('LeaguesCubit', () {
    test('lists my leagues', () async {
      when(
        () => leagues.watchMyLeagues('u1'),
      ).thenAnswer((_) => Stream.value([_family]));
      final cubit = LeaguesCubit(
        leagueRepository: leagues,
        authRepository: auth,
      );
      addTearDown(cubit.close);
      await _settle();
      expect(cubit.state.status, LeaguesStatus.ready);
      expect(cubit.state.leagues, [_family]);
    });

    test('is signed out without a user', () async {
      when(() => auth.currentUser).thenReturn(null);
      final cubit = LeaguesCubit(
        leagueRepository: leagues,
        authRepository: auth,
      );
      addTearDown(cubit.close);
      expect(cubit.state.status, LeaguesStatus.signedOut);
      verifyNever(() => leagues.watchMyLeagues(any()));
    });

    test('create returns the league, or reports why it failed', () async {
      when(
        () => leagues.watchMyLeagues('u1'),
      ).thenAnswer((_) => const Stream.empty());
      when(() => leagues.create('Family')).thenAnswer((_) async => _family);
      when(
        () => leagues.create('x'),
      ).thenThrow(const Failure('Could not create the league.'));
      final cubit = LeaguesCubit(
        leagueRepository: leagues,
        authRepository: auth,
      );
      addTearDown(cubit.close);

      expect(await cubit.create('Family'), _family);
      expect(await cubit.create('x'), isNull);
      expect(cubit.state.error, 'Could not create the league.');
      expect(cubit.state.busy, isFalse);
    });
  });

  group('JoinLeagueCubit', () {
    JoinLeagueCubit build(String code) => JoinLeagueCubit(
      code: code,
      leagueRepository: leagues,
      authRepository: auth,
    );

    test('a bad code never looks anything up', () {
      final cubit = build('nope');
      addTearDown(cubit.close);
      expect(cubit.state.status, JoinLeagueStatus.badCode);
      verifyNever(() => leagues.findByCode(any()));
    });

    test('asks a signed-out player to sign in', () async {
      when(() => auth.currentUser).thenReturn(null);
      final cubit = build('abc-234');
      addTearDown(cubit.close);
      await _settle();
      expect(cubit.state.status, JoinLeagueStatus.signedOut);
      expect(cubit.state.code, 'ABC234');
    });

    test('finds the league, then joins it', () async {
      when(() => leagues.findByCode('XYZ234')).thenAnswer((_) async => _theirs);
      when(() => leagues.join('XYZ234')).thenAnswer(
        (_) async => const League(
          id: 'L2',
          name: 'Office',
          ownerUid: 'u9',
          code: 'XYZ234',
          memberUids: ['u9', 'u1'],
        ),
      );
      final cubit = build('xyz234');
      addTearDown(cubit.close);
      await _settle();
      expect(cubit.state.status, JoinLeagueStatus.found);

      await cubit.join();

      expect(cubit.state.status, JoinLeagueStatus.joined);
      expect(cubit.state.league?.memberUids, contains('u1'));
    });

    test('says when I am already in it, or it is full or gone', () async {
      when(() => leagues.findByCode('ABC234')).thenAnswer((_) async => _family);
      final member = build('ABC234');
      addTearDown(member.close);
      await _settle();
      expect(member.state.status, JoinLeagueStatus.alreadyMember);

      when(() => leagues.findByCode('XYZ234')).thenAnswer(
        (_) async => League(
          id: 'L2',
          name: 'Office',
          ownerUid: 'u9',
          code: 'XYZ234',
          memberUids: [for (var i = 0; i < 30; i++) 'm$i'],
        ),
      );
      final full = build('XYZ234');
      addTearDown(full.close);
      await _settle();
      expect(full.state.status, JoinLeagueStatus.full);

      when(() => leagues.findByCode('QRS234')).thenAnswer((_) async => null);
      final gone = build('QRS234');
      addTearDown(gone.close);
      await _settle();
      expect(gone.state.status, JoinLeagueStatus.notFound);
    });

    test('a league that filled up while looking is reported as full', () async {
      when(() => leagues.findByCode('XYZ234')).thenAnswer((_) async => _theirs);
      when(
        () => leagues.join('XYZ234'),
      ).thenThrow(const LeagueFailure(LeagueProblem.full, 'full'));
      final cubit = build('XYZ234');
      addTearDown(cubit.close);
      await _settle();
      await cubit.join();
      expect(cubit.state.status, JoinLeagueStatus.full);
    });
  });

  group('LeagueDetailCubit', () {
    late StreamController<League?> league;

    setUp(() {
      league = StreamController<League?>.broadcast();
      when(() => leagues.watchLeague('L1')).thenAnswer((_) => league.stream);
      when(() => leagues.memberProfiles(any())).thenAnswer(
        (_) async => const {'u2': LeagueMember(uid: 'u2', displayName: 'Bo')},
      );
    });

    tearDown(() => league.close());

    LeagueDetailCubit build() => LeagueDetailCubit(
      leagueId: 'L1',
      leagueRepository: leagues,
      authRepository: auth,
    );

    test('shows the league and its members’ names', () async {
      final cubit = build();
      addTearDown(cubit.close);
      league.add(_family);
      await _settle();
      await _settle();
      expect(cubit.state.status, LeagueDetailStatus.ready);
      expect(cubit.state.isOwner, isTrue);
      expect(cubit.state.members['u2']?.displayName, 'Bo');
    });

    test('is gone once deleted, or once I am no longer in it', () async {
      final cubit = build();
      addTearDown(cubit.close);
      league.add(null);
      await _settle();
      expect(cubit.state.status, LeagueDetailStatus.gone);
      league.add(_theirs);
      await _settle();
      expect(cubit.state.status, LeagueDetailStatus.gone);
    });

    test('runs the owner’s actions and reports failures', () async {
      when(() => leagues.rename('L1', 'Cousins')).thenAnswer((_) async {});
      when(() => leagues.removeMember('L1', 'u2')).thenAnswer((_) async {});
      when(() => leagues.delete(any())).thenThrow(const Failure('nope'));
      final cubit = build();
      addTearDown(cubit.close);
      league.add(_family);
      await _settle();

      expect(await cubit.rename('Cousins'), isTrue);
      expect(await cubit.removeMember('u2'), isTrue);
      expect(await cubit.delete(), isFalse);
      expect(cubit.state.error, 'nope');
    });
  });
}
