import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/habit/freeze_saved_notice.dart';
import 'package:winklo/domain/habit/weekly_recap.dart';
import 'package:winklo/domain/repositories/habit_repository.dart';
import 'package:winklo/domain/usecases/get_weekly_recap.dart';
import 'package:winklo/features/home/cubit/home_habit_cubit.dart';

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
    test('Sunday shows this week', () async {
      final cubit = build();
      await cubit.load(currentStreaks: const {GameIds.zip: 4});
      expect(cubit.state.recap?.weekStartId, '20261012');
      expect(cubit.state.recapIsLastWeek, isFalse);
      verify(
        () => recap(
          weekStart: DateTime(2026, 10, 12),
          currentStreaks: const {GameIds.zip: 4},
        ),
      ).called(1);
    });

    test('Monday shows the week that just ended', () async {
      now = DateTime(2026, 10, 19, 8);
      final cubit = build();
      await cubit.load(currentStreaks: const {});
      expect(cubit.state.recap?.weekStartId, '20261012');
      expect(cubit.state.recapIsLastWeek, isTrue);
    });

    test('other days show none', () async {
      now = DateTime(2026, 10, 20, 8);
      final cubit = build();
      await cubit.load(currentStreaks: const {});
      expect(cubit.state.recap, isNull);
    });

    test('a week without clears shows none', () async {
      when(
        () => recap(
          weekStart: any(named: 'weekStart'),
          currentStreaks: any(named: 'currentStreaks'),
        ),
      ).thenReturn(week('20261012', cleared: 0));
      final cubit = build();
      await cubit.load(currentStreaks: const {});
      expect(cubit.state.recap, isNull);
    });

    test('dismissed stays hidden until next week', () async {
      final cubit = build();
      await cubit.load(currentStreaks: const {});
      await cubit.dismissRecap();
      expect(cubit.state.recap, isNull);
      expect(dismissed, '20261012');

      // Monday still shows the same week: hidden.
      now = DateTime(2026, 10, 19, 8);
      await cubit.load(currentStreaks: const {});
      expect(cubit.state.recap, isNull);

      // The next Sunday is a new week.
      now = DateTime(2026, 10, 25, 8);
      await cubit.load(currentStreaks: const {});
      expect(cubit.state.recap?.weekStartId, '20261019');
    });
  });

  group('freeze-saved notices', () {
    test('are taken once and kept until dismissed', () async {
      pending = [const FreezeSavedNotice(gameId: GameIds.zip, days: 12)];
      final cubit = build();
      await cubit.load(currentStreaks: const {});
      expect(cubit.state.freezeNotices, const [
        FreezeSavedNotice(gameId: GameIds.zip, days: 12),
      ]);

      await cubit.load(currentStreaks: const {});
      expect(cubit.state.freezeNotices, hasLength(1));

      cubit.dismissNotice(GameIds.zip);
      expect(cubit.state.freezeNotices, isEmpty);
    });

    test('a newer notice for a game replaces the shown one', () async {
      pending = [const FreezeSavedNotice(gameId: GameIds.zip, days: 12)];
      final cubit = build();
      await cubit.load(currentStreaks: const {});
      pending = [
        const FreezeSavedNotice(gameId: GameIds.zip, days: 13),
        const FreezeSavedNotice(gameId: GameIds.sudoku, days: 4),
      ];
      await cubit.load(currentStreaks: const {});
      expect(cubit.state.freezeNotices, const [
        FreezeSavedNotice(gameId: GameIds.zip, days: 13),
        FreezeSavedNotice(gameId: GameIds.sudoku, days: 4),
      ]);
    });
  });
}
