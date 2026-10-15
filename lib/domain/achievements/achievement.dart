import '../game_ids.dart';

enum AchievementKind {
  /// The first clear of one game.
  firstClear,

  /// A streak of [Achievement.target] days in one game.
  streak,

  /// A Zip cleared in under [Achievement.target] seconds.
  zipUnderMinute,

  /// [Achievement.target] days in a row of hint-free clears in one game.
  hintFreeWeek,

  /// [Achievement.target] Sudokus with no hints and no mistakes.
  flawlessSudokus,

  /// All three daily games cleared on the same day.
  perfectDay,
}

/// A badge players unlock from their daily clears and streaks.
class Achievement {
  const Achievement({
    required this.id,
    required this.kind,
    this.gameId,
    this.target = 1,
  });

  /// Stable id, stored in the seen set.
  final String id;
  final AchievementKind kind;

  /// The game it belongs to; null for cross-game badges.
  final String? gameId;

  /// Days, seconds or clears, depending on [kind].
  final int target;

  @override
  bool operator ==(Object other) => other is Achievement && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Achievement($id)';
}

abstract final class Achievements {
  static const streakLengths = [7, 30, 100];

  static const _games = [GameIds.zip, GameIds.pathWords, GameIds.sudoku];

  /// Every badge, in the order the grid shows them.
  static final List<Achievement> all = List.unmodifiable([
    for (final gameId in _games)
      Achievement(
        id: 'first_clear_$gameId',
        kind: AchievementKind.firstClear,
        gameId: gameId,
      ),
    const Achievement(id: 'perfect_day', kind: AchievementKind.perfectDay),
    const Achievement(
      id: 'zip_under_minute',
      kind: AchievementKind.zipUnderMinute,
      gameId: GameIds.zip,
      target: 60,
    ),
    const Achievement(
      id: 'hint_free_week',
      kind: AchievementKind.hintFreeWeek,
      target: 7,
    ),
    const Achievement(
      id: 'flawless_sudoku_10',
      kind: AchievementKind.flawlessSudokus,
      gameId: GameIds.sudoku,
      target: 10,
    ),
    for (final days in streakLengths)
      for (final gameId in _games)
        Achievement(
          id: 'streak_${days}_$gameId',
          kind: AchievementKind.streak,
          gameId: gameId,
          target: days,
        ),
  ]);

  static Achievement? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}
