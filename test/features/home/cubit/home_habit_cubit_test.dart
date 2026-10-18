import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/habit/freeze_saved_notice.dart';
import 'package:winklo/domain/habit/weekly_recap.dart';
import 'package:winklo/domain/repositories/habit_repository.dart';
import 'package:winklo/domain/usecases/get_weekly_recap.dart';
import 'package:winklo/features/home/cubit/home_habit_cubit.dart';
import 'package:winklo/features/home/cubit/home_habit_state.dart';

class _MockHabit extends Mock implements HabitRepository {}

class _MockRecap extends Mock implements GetWeeklyRecap {}

void main() {
  late _MockHabit habit;
  late _MockRecap recap;
  late DateTime now;
  late List<FreezeSavedNotice> pending;
  late String? dismissed;

  WeeklyRecap week(String start, {int cleared = 5}) =>
      WeeklyRecap(weekStartId: start, cleared: cleared, possible: 21);

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    habit = _MockHabit();
    recap = _MockRecap();
    pending = [];
    dismissed = null;
    // Sunday 18 October 2026.
    now = DateTime(2026, 10, 18, 10);
    when(() => habit.takeFreezeSavedNotices()).thenAnswer((_) async {
      final taken = pending;
      pending = [];
      return taken;
    });
    when(() => habit.dismissedRecapWeek).thenAnswer((_) => dismissed);
    when(() => habit.dismissRecapWeek(any())).thenAnswer((inv) async {
      dismissed = inv.positionalArguments.first as String;
    });
    when(
      () => recap(
        weekStart: any(named: 'weekStart'),
        currentStreaks: any(named: 'currentStreaks'),
      ),
    ).thenAnswer((inv) {
      final start = inv.namedArguments[#weekStart] as DateTime;
      final id =
          '${start.year}${start.month.toString().padLeft(2, '0')}'
          '${start.day.toString().padLeft(2, '0')}';
      return week(id);
    });
  });

  HomeHabitCubit build() =>
      HomeHabitCubit(habit: habit, weeklyRecap: recap, now: () => now);

  group('weekly recap card', () {
    blocTest<HomeHabitCubit, HomeHabitState>(
      'Sunday shows this week',
      build: build,
      act: (cubit) => cubit.load(currentStreaks: const {GameIds.zip: 4}),
      expect: () => [HomeHabitState(recap: week('20261012'))],
      verify: (_) => verify(
        () => recap(
          weekStart: DateTime(2026, 10, 12),
          currentStreaks: const {GameIds.zip: 4},
        ),
      ).called(1),
    );

    blocTest<HomeHabitCubit, HomeHabitState>(
      'Monday shows the week that just ended',
      setUp: () => now = DateTime(2026, 10, 19, 8),
      build: build,
      act: (cubit) => cubit.load(currentStreaks: const {}),
      expect: () => [
        HomeHabitState(recap: week('20261012'), recapIsLastWeek: true),
      ],
    );

    blocTest<HomeHabitCubit, HomeHabitState>(
      'other days show none',
      setUp: () => now = DateTime(2026, 10, 20, 8),
      build: build,
      act: (cubit) => cubit.load(currentStreaks: const {}),
      expect: () => <HomeHabitState>[],
    );

    blocTest<HomeHabitCubit, HomeHabitState>(
      'a week without clears shows none',
      setUp: () => when(
        () => recap(
          weekStart: any(named: 'weekStart'),
          currentStreaks: any(named: 'currentStreaks'),
        ),
      ).thenReturn(week('20261012', cleared: 0)),
      build: build,
      act: (cubit) => cubit.load(currentStreaks: const {}),
      expect: () => <HomeHabitState>[],
    );

    blocTest<HomeHabitCubit, HomeHabitState>(
      'dismissed stays hidden until next week',
      build: build,
      act: (cubit) async {
        await cubit.load(currentStreaks: const {});
        await cubit.dismissRecap();
        // Monday still shows the same week: hidden.
        now = DateTime(2026, 10, 19, 8);
        await cubit.load(currentStreaks: const {});
        // The next Sunday is a new week.
        now = DateTime(2026, 10, 25, 8);
        await cubit.load(currentStreaks: const {});
      },
      expect: () => [
        HomeHabitState(recap: week('20261012')),
        const HomeHabitState(),
        HomeHabitState(recap: week('20261019')),
      ],
      verify: (_) => expect(dismissed, '20261012'),
    );
  });

  group('freeze-saved notices', () {
    blocTest<HomeHabitCubit, HomeHabitState>(
      'are taken once and kept until dismissed',
      setUp: () => now = DateTime(2026, 10, 20, 8),
      build: build,
      act: (cubit) async {
        pending = [const FreezeSavedNotice(gameId: GameIds.zip, days: 12)];
        await cubit.load(currentStreaks: const {});
        await cubit.load(currentStreaks: const {});
        cubit.dismissNotice(GameIds.zip);
      },
      expect: () => [
        const HomeHabitState(
          freezeNotices: [FreezeSavedNotice(gameId: GameIds.zip, days: 12)],
        ),
        const HomeHabitState(),
      ],
      verify: (_) => verify(() => habit.takeFreezeSavedNotices()).called(2),
    );

    test('Home shows the newest, then the next once it is dismissed', () async {
      now = DateTime(2026, 10, 20, 8);
      pending = [
        const FreezeSavedNotice(gameId: GameIds.zip, days: 12),
        const FreezeSavedNotice(gameId: GameIds.pathWords, days: 5),
        const FreezeSavedNotice(gameId: GameIds.sudoku, days: 30),
      ];
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.load(currentStreaks: const {});

      String? shown() => cubit.state.shownFreezeNotice?.gameId;
      expect(shown(), GameIds.sudoku);
      cubit.dismissNotice(GameIds.sudoku);
      expect(shown(), GameIds.pathWords);
      cubit.dismissNotice(GameIds.pathWords);
      expect(shown(), GameIds.zip);
      cubit.dismissNotice(GameIds.zip);
      expect(shown(), isNull);
    });

    blocTest<HomeHabitCubit, HomeHabitState>(
      'a newer notice for a game replaces the shown one',
      setUp: () => now = DateTime(2026, 10, 20, 8),
      build: build,
      act: (cubit) async {
        pending = [const FreezeSavedNotice(gameId: GameIds.zip, days: 12)];
        await cubit.load(currentStreaks: const {});
        pending = [
          const FreezeSavedNotice(gameId: GameIds.zip, days: 13),
          const FreezeSavedNotice(gameId: GameIds.sudoku, days: 4),
        ];
        await cubit.load(currentStreaks: const {});
      },
      expect: () => [
        const HomeHabitState(
          freezeNotices: [FreezeSavedNotice(gameId: GameIds.zip, days: 12)],
        ),
        const HomeHabitState(
          freezeNotices: [
            FreezeSavedNotice(gameId: GameIds.zip, days: 13),
            FreezeSavedNotice(gameId: GameIds.sudoku, days: 4),
          ],
        ),
      ],
    );
  });
}
