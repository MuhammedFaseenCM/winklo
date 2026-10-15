import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/game_day_record.dart';
import 'package:winklo/domain/entities/game_history.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/usecases/load_game_history.dart';
import 'package:winklo/features/stats/cubit/stats_cubit.dart';
import 'package:winklo/features/stats/cubit/stats_state.dart';

class _MockLoadHistory extends Mock implements LoadGameHistory {}

GameHistory _history({
  List<GameDayRecord> days = const [],
  bool remoteFailed = false,
}) => GameHistory(
  days: days,
  streaks: const {GameIds.zip: GameStreak(gameId: GameIds.zip, current: 2)},
  today: DateTime(2026, 10, 15),
  remoteIncluded: !remoteFailed,
  remoteFailed: remoteFailed,
);

const _zipClear = GameDayRecord(
  gameId: GameIds.zip,
  playId: '20261015',
  timeSeconds: 45,
  usedHints: false,
  hadMistakes: false,
  flagsKnown: true,
);

void main() {
  late _MockLoadHistory load;

  setUp(() {
    load = _MockLoadHistory();
    when(
      () => load(refreshRemote: any(named: 'refreshRemote')),
    ).thenAnswer((_) async => _history(days: const [_zipClear]));
  });

  blocTest<StatsCubit, StatsState>(
    'loads stats per game and the earned achievements',
    build: () => StatsCubit(loadHistory: load),
    expect: () => [
      isA<StatsState>()
          .having((s) => s.status, 'status', StatsStatus.ready)
          .having((s) => s.stats.keys, 'games', [
            GameIds.zip,
            GameIds.pathWords,
            GameIds.sudoku,
          ])
          .having((s) => s.stats[GameIds.zip]!.clears, 'zip clears', 1)
          .having((s) => s.stats[GameIds.zip]!.currentStreak, 'streak', 2)
          .having((s) => s.stats[GameIds.sudoku]!.clears, 'sudoku', 0)
          .having((s) => s.unlocked, 'unlocked', {
            'first_clear_zip',
            'zip_under_minute',
          })
          .having((s) => s.remoteFailed, 'remoteFailed', isFalse),
    ],
    verify: (_) => verify(() => load(refreshRemote: false)).called(1),
  );

  blocTest<StatsCubit, StatsState>(
    'can ask for a fresh remote copy on creation and on refresh',
    build: () => StatsCubit(loadHistory: load, refreshRemote: true),
    act: (cubit) async {
      await Future<void>.delayed(Duration.zero);
      await cubit.load(refresh: true);
    },
    verify: (_) => verify(() => load(refreshRemote: true)).called(2),
  );

  blocTest<StatsCubit, StatsState>(
    'reports when only this device could be counted',
    setUp: () => when(
      () => load(refreshRemote: any(named: 'refreshRemote')),
    ).thenAnswer((_) async => _history(remoteFailed: true)),
    build: () => StatsCubit(loadHistory: load),
    expect: () => [
      isA<StatsState>().having((s) => s.remoteFailed, 'remoteFailed', isTrue),
    ],
  );

  group('progress changes', () {
    late StreamController<void> changes;
    late StreamController<void> restored;

    setUp(() {
      changes = StreamController<void>.broadcast();
      restored = StreamController<void>.broadcast();
    });
    tearDown(() async {
      await changes.close();
      await restored.close();
    });

    blocTest<StatsCubit, StatsState>(
      'reload once per burst of changes and restores',
      build: () => StatsCubit(
        loadHistory: load,
        reloadOn: [changes.stream, restored.stream],
        reloadDebounce: const Duration(milliseconds: 20),
      ),
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        changes
          ..add(null)
          ..add(null);
        restored.add(null);
        await Future<void>.delayed(const Duration(milliseconds: 60));
      },
      verify: (_) => verify(() => load(refreshRemote: false)).called(2),
    );
  });

  blocTest<StatsCubit, StatsState>(
    'emits failure when the first load throws',
    setUp: () => when(
      () => load(refreshRemote: any(named: 'refreshRemote')),
    ).thenAnswer((_) async => throw const Failure('boom')),
    build: () => StatsCubit(loadHistory: load),
    expect: () => [
      isA<StatsState>().having((s) => s.status, 'status', StatsStatus.failure),
    ],
  );

  blocTest<StatsCubit, StatsState>(
    'keeps the last good data when a reload throws',
    build: () => StatsCubit(loadHistory: load),
    act: (cubit) async {
      await Future<void>.delayed(Duration.zero);
      when(
        () => load(refreshRemote: any(named: 'refreshRemote')),
      ).thenThrow(const Failure('boom'));
      await cubit.load(refresh: true);
    },
    expect: () => [
      isA<StatsState>().having((s) => s.status, 'status', StatsStatus.ready),
    ],
  );
}
