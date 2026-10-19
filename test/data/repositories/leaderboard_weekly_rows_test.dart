import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/data/repositories/leaderboard_repository_impl.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';

void main() {
  group('mapWeeklyLeaderboardRows', () {
    test('reads days and totals, with dense ranks on equal pairs', () {
      final entries = mapWeeklyLeaderboardRows([
        (
          id: 'a',
          data: {
            'displayName': 'Ada',
            'daysCleared': 5,
            'totalSeconds': 372,
            'days': {'2026-10-12': 60},
            'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 15)),
          },
        ),
        (id: 'b', data: {'daysCleared': 5, 'totalSeconds': 372}),
        (id: 'c', data: {'daysCleared': 4, 'totalSeconds': 100}),
      ]);
      expect(entries.map((e) => e.rank), [1, 1, 2]);
      expect(entries.first.timeSeconds, 372);
      expect(entries.first.daysCleared, 5);
      expect(entries.first.updatedAt.toUtc(), DateTime.utc(2026, 10, 15));
      expect(entries[1].displayName, 'Player');
    });

    test('skips rows without days or a total', () {
      final entries = mapWeeklyLeaderboardRows([
        (id: 'a', data: {'daysCleared': 0, 'totalSeconds': 10}),
        (id: 'b', data: {'daysCleared': 2}),
        (id: 'c', data: {'daysCleared': '2', 'totalSeconds': 10}),
        (id: 'd', data: {'daysCleared': 1, 'totalSeconds': 30}),
      ]);
      expect(entries.map((e) => e.uid), ['d']);
      expect(entries.single.rank, 1);
    });
  });

  group('aggregateWeeklyFromDailyRows', () {
    test('sums days and totals like the Worker weekly write', () {
      final entries = aggregateWeeklyFromDailyRows({
        '2026-10-12': [
          (
            id: 'a',
            data: {
              'timeSeconds': 60,
              'displayName': 'Ada',
              'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 12)),
            },
          ),
          (
            id: 'b',
            data: {
              'timeSeconds': 90,
              'displayName': 'Bea',
              'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 12)),
            },
          ),
        ],
        '2026-10-13': [
          (
            id: 'a',
            data: {
              'timeSeconds': 50,
              'displayName': 'Ada',
              'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 13)),
            },
          ),
        ],
      });
      expect(entries.map((e) => e.uid), ['a', 'b']);
      expect(entries.first.daysCleared, 2);
      expect(entries.first.timeSeconds, 110);
      expect(entries.last.daysCleared, 1);
      expect(entries.last.timeSeconds, 90);
    });
  });

  test('debug builds have no weekly board', () async {
    final wasReady = FirebaseBootstrap.isReady;
    addTearDown(() => FirebaseBootstrap.isReady = wasReady);
    FirebaseBootstrap.isReady = true;
    final repo = LeaderboardRepositoryImpl(
      firestore: _NoFirestore(),
      isDebugMode: true,
    );
    expect(
      await repo
          .watchBoard(gameId: 'zip', period: LeaderboardPeriod.weekly)
          .first,
      isEmpty,
    );
    expect(
      await repo
          .watchMembersBoard(
            gameId: 'zip',
            period: LeaderboardPeriod.weekly,
            memberUids: const ['u1'],
          )
          .first,
      isEmpty,
    );
  });

  test('a league with no members has an empty board', () async {
    final wasReady = FirebaseBootstrap.isReady;
    addTearDown(() => FirebaseBootstrap.isReady = wasReady);
    FirebaseBootstrap.isReady = true;
    final repo = LeaderboardRepositoryImpl(
      firestore: _NoFirestore(),
      isDebugMode: false,
    );
    expect(
      await repo
          .watchMembersBoard(
            gameId: 'zip',
            period: LeaderboardPeriod.daily,
            memberUids: const [],
          )
          .first,
      isEmpty,
    );
  });
}

/// Fails the test if the repository touches Firestore at all.
class _NoFirestore extends Fake implements FirebaseFirestore {}
