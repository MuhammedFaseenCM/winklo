/**
 * Shapes today's puzzle docs and leaderboard entries for the landing page.
 *
 * Only what the page draws leaves here: a Zip board's numbers and walls, a
 * Sudoku board's givens, a Path Words board's letters and word count. The
 * solution, Zip's path and Path Words' words and routes never do.
 */

import { MAX_SECONDS, MIN_SECONDS, type GameId } from '../../leaderboard/src/limits';

export type ZipBoard = {
  size: number;
  /** `[row, col, number]`, in number order. */
  numbers: [number, number, number][];
  /** `[rowA, colA, rowB, colB]`: a wall between two neighbouring cells. */
  walls: [number, number, number, number][];
};

export type SudokuBoard = {
  size: number;
  boxRows: number;
  boxCols: number;
  /** Row by row; 0 is an empty cell. */
  given: number[];
};

export type PathWordsBoard = {
  size: number;
  /** Row by row; '' is a gap in the grid. */
  letters: string[];
  words: number;
};

export type Board = ZipBoard | SudokuBoard | PathWordsBoard;

export type TopEntry = {
  name: string;
  timeSeconds: number;
  hintFree: boolean;
  flawless: boolean;
  streak: number;
};

export type GameToday = {
  difficulty: string | null;
  board: Board | null;
  /** Null when the leaderboard couldn't be read. */
  clears: number | null;
  top: TopEntry[] | null;
};

export type Today = {
  day: string;
  updatedAt: string;
  games: Record<GameId, GameToday>;
};

/** The puzzle fields each board needs, for the REST read's field mask. */
export const PUZZLE_FIELDS: Record<GameId, string[]> = {
  zip: ['size', 'numbers', 'walls', 'difficulty'],
  // `targets` holds the words; it's read here only to count them.
  path_words: ['size', 'letters', 'targets', 'difficulty'],
  sudoku: ['size', 'boxRows', 'boxCols', 'given', 'difficulty'],
};

/** The leaderboard entry fields the page uses (no uid, photo or avatar). */
export const ENTRY_FIELDS = [
  'timeSeconds',
  'displayName',
  'usedHints',
  'hadMistakes',
  'currentStreak',
] as const;

const MAX_BOARD_SIZE = 12;

function isBoardSize(value: unknown): value is number {
  return Number.isInteger(value) && (value as number) >= 2 && (value as number) <= MAX_BOARD_SIZE;
}

function isCell(value: unknown, size: number): value is [number, number] {
  return (
    Array.isArray(value) &&
    value.length === 2 &&
    value.every((n) => Number.isInteger(n) && n >= 0 && n < size)
  );
}

export function zipBoard(data: Record<string, unknown>): ZipBoard | null {
  const size = data.size;
  if (!isBoardSize(size)) return null;
  const numbers: [number, number, number][] = [];
  const raw = data.numbers;
  if (!raw || typeof raw !== 'object') return null;
  for (const [key, value] of Object.entries(raw as Record<string, unknown>)) {
    const cell = key.split(',').map(Number);
    if (!isCell(cell, size) || !Number.isInteger(value)) return null;
    numbers.push([cell[0], cell[1], value as number]);
  }
  numbers.sort((a, b) => a[2] - b[2]);
  const walls: [number, number, number, number][] = [];
  for (const wall of Array.isArray(data.walls) ? data.walls : []) {
    const { a, b } = (wall ?? {}) as { a?: unknown; b?: unknown };
    if (!isCell(a, size) || !isCell(b, size)) return null;
    walls.push([a[0], a[1], b[0], b[1]]);
  }
  return { size, numbers, walls };
}

export function sudokuBoard(data: Record<string, unknown>): SudokuBoard | null {
  const { size, boxRows, boxCols, given } = data;
  if (!isBoardSize(size)) return null;
  if (!Number.isInteger(boxRows) || !Number.isInteger(boxCols)) return null;
  if ((boxRows as number) * (boxCols as number) !== size) return null;
  if (!Array.isArray(given) || given.length !== size * size) return null;
  if (!given.every((n) => Number.isInteger(n) && n >= 0 && n <= size)) return null;
  return { size, boxRows: boxRows as number, boxCols: boxCols as number, given: given as number[] };
}

export function pathWordsBoard(data: Record<string, unknown>): PathWordsBoard | null {
  const { size, letters, targets } = data;
  if (!isBoardSize(size)) return null;
  if (!Array.isArray(letters) || letters.length !== size * size) return null;
  if (!letters.every((l) => typeof l === 'string' && [...l].length <= 1)) return null;
  if (!Array.isArray(targets) || targets.length === 0) return null;
  return {
    size,
    letters: (letters as string[]).map((l) => l.toUpperCase()),
    words: targets.length,
  };
}

export function boardFor(game: GameId, data: Record<string, unknown>): Board | null {
  switch (game) {
    case 'zip':
      return zipBoard(data);
    case 'sudoku':
      return sudokuBoard(data);
    case 'path_words':
      return pathWordsBoard(data);
  }
}

export function difficultyOf(data: Record<string, unknown>): string | null {
  return typeof data.difficulty === 'string' ? data.difficulty : null;
}

/**
 * A leaderboard name for the open web: the first word and the last word's
 * initial ("Arun Kumar" → "Arun K."). The full name stays in the app.
 */
export function shortName(displayName: unknown): string {
  const words = typeof displayName === 'string' ? displayName.trim().split(/\s+/).filter(Boolean) : [];
  if (words.length === 0) return 'Player';
  const first = [...words[0]].slice(0, 16).join('');
  if (words.length === 1) return first;
  const initial = [...words[words.length - 1]][0].toUpperCase();
  return `${first} ${initial}.`;
}

/**
 * An entry the page can show, or null for a time the leaderboard Worker
 * would refuse (older builds wrote some before the minimums existed).
 */
export function topEntry(game: GameId, data: Record<string, unknown>): TopEntry | null {
  const time = data.timeSeconds;
  if (!Number.isInteger(time)) return null;
  if ((time as number) < MIN_SECONDS[game] || (time as number) > MAX_SECONDS) return null;
  const streak = data.currentStreak;
  return {
    name: shortName(data.displayName),
    timeSeconds: time as number,
    // The app's chip rules (lib/core/strings/clean_run_chips.dart).
    hintFree: data.usedHints === false,
    flawless: game === 'sudoku' && data.hadMistakes === false,
    streak: Number.isInteger(streak) && (streak as number) > 0 ? (streak as number) : 0,
  };
}
