import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/entities/league.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/league_repository.dart';
import 'package:winklo/domain/usecases/watch_leaderboard.dart';
import 'package:winklo/features/leaderboard/cubit/leaderboard_cubit.dart';
import 'package:winklo/features/leaderboard/cubit/leaderboard_state.dart';

class _MockWatchLeaderboard extends Mock implements WatchLeaderboard {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockLeagueRepository extends Mock implements LeagueRepository {}

const _family = League(
  id: 'L1',
  name: 'Family',
  ownerUid: 'u1',
  code: 'ABC234',
  memberUids: ['u1', 'u2'],
);

/// Past days, leagues and the weekly board on the cubit.
void main() {
  late _MockWatchLeaderboard watch;
  late _MockAuthRepository auth;
  late _MockLeagueRepository leagues;
  late StreamController<List<League>> leaguesController;
  late List<({LeaderboardPeriod period, String? dayId, List<String>? members})>
  calls;

  setUpAll(() {
    registerFallbackValue(LeaderboardPeriod.daily);
  });

  setUp(() {
    watch = _MockWatchLeaderboard();
    auth = _MockAuthRepository();
    leagues = _MockLeagueRepository();
    leaguesController = StreamController<List<League>>.broadcast();
    calls = [];
    when(
      () => auth.currentUser,
    ).thenReturn(const AppUser(uid: 'u1', displayName: 'Ada'));
    when(() => auth.authStateChanges()).thenAnswer((_) => const Stream.empty());
    when(
      () => leagues.watchMyLeagues(any()),
    ).thenAnswer((_) => leaguesController.stream);
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((invocation) {
      calls.add((
        period: invocation.namedArguments[#period] as LeaderboardPeriod,
        dayId: invocation.namedArguments[#dayId] as String?,
        members: null,
      ));
      return const Stream<List<LeaderboardEntry>>.empty();
    });
    when(
      () => watch.members(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        memberUids: any(named: 'memberUids'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((invocation) {
      calls.add((
        period: invocation.namedArguments[#period] as LeaderboardPeriod,
        dayId: invocation.namedArguments[#dayId] as String?,
        members: invocation.namedArguments[#memberUids] as List<String>,
      ));
      return const Stream<List<LeaderboardEntry>>.empty();
    });
  });

  tearDown(() => leaguesController.close());

  LeaderboardCubit build() => LeaderboardCubit(
    watchLeaderboard: watch,
    authRepository: auth,
    leagueRepository: leagues,
    now: () => DateTime(2026, 10, 15, 9),
  );

  test('the day strip is today and the 13 days before it', () async {
    final cubit = build();
    addTearDown(cubit.close);
    expect(cubit.recentDayIds.first, '2026-10-15');
    expect(cubit.recentDayIds, hasLength(14));
    expect(cubit.recentDayIds.last, '2026-10-02');
  });

  test('selectDay loads that day; today goes back to the live board', () {
    final cubit = build();
    addTearDown(cubit.close);

    cubit.selectDay('2026-10-13');
    expect(cubit.state.dayId, '2026-10-13');
    expect(calls.last.dayId, '2026-10-13');

    cubit.selectDay('2026-10-15');
    expect(cubit.state.dayId, isNull);
    expect(calls.last.dayId, isNull);
  });

  test('selectDay ignores days outside the strip', () {
    final cubit = build();
    addTearDown(cubit.close);
    final before = calls.length;
    cubit.selectDay('2026-09-01');
    expect(cubit.state.dayId, isNull);
    expect(calls, hasLength(before));
  });

  test('weekly and all-time boards ignore the picked day', () {
    final cubit = build();
    addTearDown(cubit.close);
    cubit.selectDay('2026-10-13');
    cubit.selectPeriod(LeaderboardPeriod.weekly);
    expect(calls.last, (
      period: LeaderboardPeriod.weekly,
      dayId: null,
      members: null,
    ));
    cubit.selectPeriod(LeaderboardPeriod.daily);
    expect(calls.last.dayId, '2026-10-13');
  });

  test('my leagues fill the scope picker', () async {
    final cubit = build();
    addTearDown(cubit.close);
    leaguesController.add([_family]);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.leagues, [_family]);
    verify(() => leagues.watchMyLeagues('u1')).called(1);
  });

  test('a league scope shows its members on the same board', () async {
    final cubit = build();
    addTearDown(cubit.close);
    leaguesController.add([_family]);
    await Future<void>.delayed(Duration.zero);

    cubit.selectLeague('L1');
    expect(cubit.state.league, _family);
    expect(calls.last.members, ['u1', 'u2']);

    cubit.selectDay('2026-10-14');
    expect(calls.last.period, LeaderboardPeriod.daily);
    expect(calls.last.dayId, '2026-10-14');
    expect(calls.last.members, ['u1', 'u2']);

    cubit.selectLeague(null);
    expect(calls.last.members, isNull);
  });

  test(
    'a league picked before my leagues load is shown once they do',
    () async {
      final cubit = build();
      addTearDown(cubit.close);
      cubit.selectLeague('L1');
      expect(cubit.state.leagueId, isNull);

      leaguesController.add([_family]);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.leagueId, 'L1');
      expect(calls.last.members, ['u1', 'u2']);
    },
  );

  test('ignores a league that is not mine', () {
    final cubit = build();
    addTearDown(cubit.close);
    cubit.selectLeague('nope');
    expect(cubit.state.leagueId, isNull);
  });

  test('falls back to everyone when the league goes away', () async {
    final cubit = build();
    addTearDown(cubit.close);
    leaguesController.add([_family]);
    await Future<void>.delayed(Duration.zero);
    cubit.selectLeague('L1');

    leaguesController.add(const []);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.leagueId, isNull);
    expect(cubit.state.status, LeaderboardStatus.loading);
    expect(calls.last.members, isNull);
  });

  test('reloads when the members change', () async {
    final cubit = build();
    addTearDown(cubit.close);
    leaguesController.add([_family]);
    await Future<void>.delayed(Duration.zero);
    cubit.selectLeague('L1');

    leaguesController.add([
      const League(
        id: 'L1',
        name: 'Family',
        ownerUid: 'u1',
        code: 'ABC234',
        memberUids: ['u1', 'u2', 'u3'],
      ),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(calls.last.members, ['u1', 'u2', 'u3']);
  });

  test('the Results mini board works without leagues', () {
    final cubit = LeaderboardCubit(
      watchLeaderboard: watch,
      authRepository: auth,
    );
    addTearDown(cubit.close);
    expect(cubit.state.leagues, isEmpty);
    expect(calls, hasLength(1));
  });

  group('selectBoard', () {
    test('a past day loads once, with that day', () {
      final cubit = build();
      addTearDown(cubit.close);
      final before = calls.length;

      cubit.selectBoard(LeaderboardPeriod.daily, dayId: '2026-10-13');

      expect(calls, hasLength(before + 1));
      expect(calls.last.period, LeaderboardPeriod.daily);
      expect(calls.last.dayId, '2026-10-13');
      expect(cubit.state.dayId, '2026-10-13');
    });

    test('from a past day to This week: one load, day cleared', () {
      final cubit = build();
      addTearDown(cubit.close);
      cubit.selectBoard(LeaderboardPeriod.daily, dayId: '2026-10-13');
      final before = calls.length;

      cubit.selectBoard(LeaderboardPeriod.weekly);

      expect(calls, hasLength(before + 1));
      expect(calls.last.period, LeaderboardPeriod.weekly);
      expect(cubit.state.period, LeaderboardPeriod.weekly);
      expect(cubit.state.dayId, isNull);
    });

    test('from This week to a past day: one load', () {
      final cubit = build();
      addTearDown(cubit.close);
      cubit.selectBoard(LeaderboardPeriod.weekly);
      final before = calls.length;

      cubit.selectBoard(LeaderboardPeriod.daily, dayId: '2026-10-14');

      expect(calls, hasLength(before + 1));
      expect(calls.last, (
        period: LeaderboardPeriod.daily,
        dayId: '2026-10-14',
        members: null,
      ));
    });

    test('today is the live board (null day)', () {
      final cubit = build();
      addTearDown(cubit.close);
      cubit.selectBoard(LeaderboardPeriod.daily, dayId: '2026-10-13');

      cubit.selectBoard(LeaderboardPeriod.daily, dayId: '2026-10-15');

      expect(cubit.state.dayId, isNull);
      expect(calls.last.dayId, isNull);
    });

    test('the board already showing does nothing', () {
      final cubit = build();
      addTearDown(cubit.close);
      final before = calls.length;
      cubit.selectBoard(LeaderboardPeriod.daily);
      cubit.selectBoard(LeaderboardPeriod.daily, dayId: '2026-10-15');
      expect(calls, hasLength(before));
    });

    test('a day outside the window is ignored', () {
      final cubit = build();
      addTearDown(cubit.close);
      final before = calls.length;
      cubit.selectBoard(LeaderboardPeriod.daily, dayId: '2026-09-01');
      expect(calls, hasLength(before));
      expect(cubit.state.dayId, isNull);
    });
  });
}
