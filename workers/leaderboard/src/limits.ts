/**
 * The leaderboard's fixed limits, in one place.
 *
 * `test/firestore/leaderboard_fair_play_pins_test.dart` pins these against
 * `lib/domain/leaderboard_limits.dart`, `firestore/firestore.rules` and the
 * app's field lists, so changing one without the others fails the app tests.
 */

export const GAMES = ['zip', 'path_words', 'sudoku'] as const;

export type GameId = (typeof GAMES)[number];

export function isGameId(value: unknown): value is GameId {
  return typeof value === 'string' && (GAMES as readonly string[]).includes(value);
}

/**
 * Fastest accepted clear, in whole seconds (also `minLeaderboardSeconds` in
 * the rules). Held at 1 for every game: there is no speed floor beyond a
 * positive whole second; the proof check stops forged clears.
 */
export const MIN_SECONDS: Record<GameId, number> = {
  zip: 1,
  path_words: 1,
  sudoku: 1,
};

/** Slowest accepted clear: one day. */
export const MAX_SECONDS = 86_400;

/** Where each game's daily puzzle lives: `{collection}/daily_{YYYYMMDD}`. */
export const PUZZLE_COLLECTIONS: Record<GameId, string> = {
  zip: 'zip_levels',
  path_words: 'path_words_levels',
  sudoku: 'sudoku_levels',
};

/** The only leaderboard root this Worker writes; debug builds write `leaderboards_debug` directly. */
export const LEADERBOARD_ROOT = 'leaderboards';

/** Fields on a daily or all-time entry (the rules' `validLeaderboardKeys`). */
export const ENTRY_FIELDS = [
  'timeSeconds',
  'updatedAt',
  'displayName',
  'photoUrl',
  'avatarId',
  'usedHints',
  'hadMistakes',
  'currentStreak',
] as const;

/** Fields on a weekly entry (`leaderboards/{gameId}/weekly/{weekId}/entries/{uid}`). */
export const WEEKLY_FIELDS = [
  'displayName',
  'photoUrl',
  'avatarId',
  'days',
  'daysCleared',
  'totalSeconds',
  'updatedAt',
] as const;

/** Games with a Levels board (`leaderboards/{gameId}/levels/{uid}`). */
export const LEVEL_GAMES = ['zip'] as const;

export type LevelGameId = (typeof LEVEL_GAMES)[number];

/** Fields on a Levels board row (`leaderboards/{gameId}/levels/{uid}`). */
export const LEVEL_BOARD_FIELDS = [
  'stars',
  'levelsCleared',
  'timeSeconds',
  'displayName',
  'photoUrl',
  'avatarId',
  'updatedAt',
] as const;

/** Fields on the server's level bests (`leaderboards/{gameId}/level_records/{uid}`). */
export const LEVEL_RECORD_FIELDS = ['levels', 'updatedAt'] as const;
