import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/habit/game_habit_status.dart';
import 'package:winklo/domain/habit/home_widget_snapshot.dart';

void main() {
  final now = DateTime(2026, 10, 31, 15);

  GameHabitStatus game(
    String gameId, {
    int current = 0,
    String? last,
    int freezes = 1,
    bool cleared = false,
  }) => GameHabitStatus(
    streak: GameStreak(
      gameId: gameId,
      current: current,
      longest: current,
      lastClearedDateId: last,
      freezeCount: freezes,
    ),
    clearedToday: cleared,
  );

  test('day ids are today and tomorrow, across a month end', () {
    final snapshot = HomeWidgetSnapshot.build(games: const [], now: now);
    expect(snapshot.dayId, '20261031');
    expect(snapshot.nextDayId, '20261101');
  });

  test('today: cleared is a tick, a streak is fire, nothing is play', () {
    final snapshot = HomeWidgetSnapshot.build(
      games: [
        game(GameIds.zip, current: 4, last: '20261031', cleared: true),
        game(GameIds.pathWords, current: 12, last: '20261030'),
        game(GameIds.sudoku),
      ],
      now: now,
    );
    expect(snapshot.today, const [
      HomeWidgetLine(gameId: GameIds.zip, mark: HomeWidgetMark.cleared),
      HomeWidgetLine(
        gameId: GameIds.pathWords,
        mark: HomeWidgetMark.streak,
        streak: 12,
      ),
      HomeWidgetLine(gameId: GameIds.sudoku, mark: HomeWidgetMark.play),
    ]);
  });

  test('a clear the streak knows of counts even without a score', () {
    final snapshot = HomeWidgetSnapshot.build(
      games: [game(GameIds.zip, current: 4, last: '20261031')],
      now: now,
    );
    expect(snapshot.today.single.mark, HomeWidgetMark.cleared);
  });

  test('tomorrow shows what a day without play would leave', () {
    final snapshot = HomeWidgetSnapshot.build(
      games: [
        game(GameIds.zip, current: 4, last: '20261031', cleared: true),
        game(GameIds.pathWords, current: 12, last: '20261030', freezes: 0),
        game(GameIds.sudoku, current: 3, last: '20261030'),
      ],
      now: now,
    );
    expect(snapshot.tomorrow, const [
      HomeWidgetLine(
        gameId: GameIds.zip,
        mark: HomeWidgetMark.streak,
        streak: 4,
      ),
      HomeWidgetLine(gameId: GameIds.pathWords, mark: HomeWidgetMark.play),
      HomeWidgetLine(
        gameId: GameIds.sudoku,
        mark: HomeWidgetMark.streak,
        streak: 3,
      ),
    ]);
  });
}
