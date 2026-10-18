/**
 * Checks that a submitted proof solves the stored daily puzzle, with the
 * same rules the app plays by (`PathValidator.isWon`, `SudokuPuzzle`,
 * `PathWordsRules.completedTarget`).
 *
 * Puzzle docs come from Firestore as decoded JSON. Firestore can't store
 * nested arrays, so the admin tools write cells inside arrays as `{row, col}`
 * maps and lone cells as `[r, c]`; the app's `Cell.fromJson` also reads
 * `"r,c"`. Puzzle cells accept all three. Proof cells come from this build of
 * the app and must be `[r, c]` pairs of integers.
 */

import type { GameId } from './limits';

export type Cell = [number, number];

type Json = Record<string, unknown>;

function isInt(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value);
}

function isObject(value: unknown): value is Json {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/** A puzzle cell in any form the app reads, or null. */
export function parseCell(value: unknown): Cell | null {
  if (Array.isArray(value)) {
    return value.length === 2 && isInt(value[0]) && isInt(value[1])
      ? [value[0], value[1]]
      : null;
  }
  if (isObject(value)) {
    return isInt(value.row) && isInt(value.col) ? [value.row, value.col] : null;
  }
  if (typeof value === 'string') {
    const match = /^(-?\d+),(-?\d+)$/.exec(value);
    return match ? [Number(match[1]), Number(match[2])] : null;
  }
  return null;
}

/** A proof cell: exactly `[r, c]` integers. */
function proofCell(value: unknown): Cell | null {
  return Array.isArray(value) ? parseCell(value) : null;
}

function proofCells(value: unknown, maxLength: number): Cell[] | null {
  if (!Array.isArray(value) || value.length === 0 || value.length > maxLength) {
    return null;
  }
  const cells: Cell[] = [];
  for (const item of value) {
    const cell = proofCell(item);
    if (!cell) return null;
    cells.push(cell);
  }
  return cells;
}

function key([r, c]: Cell): string {
  return `${r},${c}`;
}

function edgeKey(a: Cell, b: Cell): string {
  const [first, second] = [key(a), key(b)].sort();
  return `${first}|${second}`;
}

function inBounds([r, c]: Cell, size: number): boolean {
  return r >= 0 && r < size && c >= 0 && c < size;
}

function orthogonal(a: Cell, b: Cell): boolean {
  return Math.abs(a[0] - b[0]) + Math.abs(a[1] - b[1]) === 1;
}

/** Biggest board any game uses, to bound the work a proof can cause. */
const MAX_SIZE = 12;

function boardSize(value: unknown): number | null {
  return isInt(value) && value >= 1 && value <= MAX_SIZE ? value : null;
}

// ---------------------------------------------------------------- Zip

export type ZipPuzzle = {
  size: number;
  numbers: Map<string, number>;
  walls: Set<string>;
  maxNumber: number;
};

export function parseZipPuzzle(doc: Json): ZipPuzzle | null {
  const size = boardSize(doc.size);
  if (size === null || !isObject(doc.numbers)) return null;
  const numbers = new Map<string, number>();
  for (const [cellKey, n] of Object.entries(doc.numbers)) {
    const cell = parseCell(cellKey);
    if (!cell || !inBounds(cell, size) || !isInt(n) || n < 1) return null;
    numbers.set(key(cell), n);
  }
  if (numbers.size === 0) return null;
  const walls = new Set<string>();
  const rawWalls = doc.walls ?? [];
  if (!Array.isArray(rawWalls)) return null;
  for (const wall of rawWalls) {
    if (!isObject(wall)) return null;
    const a = parseCell(wall.a);
    const b = parseCell(wall.b);
    if (!a || !b) return null;
    walls.add(edgeKey(a, b));
  }
  return { size, numbers, walls, maxNumber: Math.max(...numbers.values()) };
}

/**
 * The path starts on 1, visits every cell once in orthogonal steps, never
 * crosses a wall, meets the numbers in order and ends on the last one.
 */
export function checkZipProof(puzzle: ZipPuzzle, proof: unknown): boolean {
  if (!isObject(proof)) return false;
  const cellCount = puzzle.size * puzzle.size;
  const path = proofCells(proof.path, cellCount);
  if (!path || path.length !== cellCount) return false;
  const seen = new Set<string>();
  let next = 1;
  for (let i = 0; i < path.length; i++) {
    const cell = path[i];
    if (!inBounds(cell, puzzle.size)) return false;
    const k = key(cell);
    if (seen.has(k)) return false;
    seen.add(k);
    if (i > 0) {
      const previous = path[i - 1];
      if (!orthogonal(previous, cell)) return false;
      if (puzzle.walls.has(edgeKey(previous, cell))) return false;
    }
    const n = puzzle.numbers.get(k);
    if (n !== undefined) {
      if (n !== next) return false;
      next += 1;
    } else if (i === 0) {
      return false;
    }
  }
  return (
    next === puzzle.maxNumber + 1 &&
    puzzle.numbers.get(key(path[path.length - 1])) === puzzle.maxNumber
  );
}

// ---------------------------------------------------------------- Sudoku

export type SudokuPuzzle = { solution: number[] };

/** Only the 6×6 board with 2×3 boxes, the one shape the app plays. */
export function parseSudokuPuzzle(doc: Json): SudokuPuzzle | null {
  const size = doc.size ?? 6;
  const boxRows = doc.boxRows ?? 2;
  const boxCols = doc.boxCols ?? 3;
  if (size !== 6 || boxRows !== 2 || boxCols !== 3) return null;
  const solution = doc.solution;
  if (!Array.isArray(solution) || solution.length !== 36) return null;
  if (!solution.every((v) => isInt(v) && v >= 1 && v <= 6)) return null;
  return { solution: solution as number[] };
}

export function checkSudokuProof(puzzle: SudokuPuzzle, proof: unknown): boolean {
  if (!isObject(proof)) return false;
  const grid = proof.grid;
  if (!Array.isArray(grid) || grid.length !== puzzle.solution.length) return false;
  return grid.every((v, i) => v === puzzle.solution[i]);
}

// ---------------------------------------------------------------- Path Words

export type PathWordsTarget = { id: string; word: string; path: Cell[] };

export type PathWordsPuzzle = {
  size: number;
  letters: string[];
  targets: PathWordsTarget[];
};

export function parsePathWordsPuzzle(doc: Json): PathWordsPuzzle | null {
  const size = boardSize(doc.size);
  if (size === null || !Array.isArray(doc.letters)) return null;
  if (doc.letters.length !== size * size) return null;
  const letters = doc.letters.map((l) =>
    typeof l === 'string' ? l.toLowerCase() : null,
  );
  if (letters.some((l) => l === null)) return null;
  if (!Array.isArray(doc.targets) || doc.targets.length === 0) return null;
  const targets: PathWordsTarget[] = [];
  const ids = new Set<string>();
  for (const raw of doc.targets) {
    if (!isObject(raw)) return null;
    if (typeof raw.id !== 'string' || typeof raw.word !== 'string') return null;
    if (!Array.isArray(raw.path) || ids.has(raw.id)) return null;
    const path: Cell[] = [];
    for (const item of raw.path) {
      const cell = parseCell(item);
      if (!cell) return null;
      path.push(cell);
    }
    ids.add(raw.id);
    targets.push({ id: raw.id, word: raw.word.toLowerCase(), path });
  }
  return { size, letters: letters as string[], targets };
}

function samePath(a: Cell[], b: Cell[]): boolean {
  return a.length === b.length && a.every((cell, i) => key(cell) === key(b[i]));
}

/**
 * Each target is traced exactly once, along adjacent lettered cells, and its
 * stroke is either the stored route or another route that spells the word and
 * stays off every other word's stored cells (as the app accepts). No cell is
 * used by two strokes.
 */
export function checkPathWordsProof(
  puzzle: PathWordsPuzzle,
  proof: unknown,
): boolean {
  if (!isObject(proof) || !Array.isArray(proof.strokes)) return false;
  if (proof.strokes.length !== puzzle.targets.length) return false;
  const byId = new Map(puzzle.targets.map((t) => [t.id, t]));
  const traced = new Set<string>();
  const used = new Set<string>();
  const cellCount = puzzle.size * puzzle.size;
  for (const stroke of proof.strokes) {
    if (!isObject(stroke) || typeof stroke.targetId !== 'string') return false;
    const target = byId.get(stroke.targetId);
    if (!target || traced.has(target.id)) return false;
    traced.add(target.id);
    const cells = proofCells(stroke.cells, cellCount);
    if (!cells) return false;
    for (let i = 0; i < cells.length; i++) {
      const cell = cells[i];
      if (!inBounds(cell, puzzle.size)) return false;
      if (!puzzle.letters[cell[0] * puzzle.size + cell[1]]) return false;
      const k = key(cell);
      if (used.has(k)) return false;
      used.add(k);
      if (i > 0 && !orthogonal(cells[i - 1], cell)) return false;
    }
    if (samePath(cells, target.path)) continue;
    const spelled = cells
      .map(([r, c]) => puzzle.letters[r * puzzle.size + c])
      .join('');
    if (spelled !== target.word) return false;
    const othersCells = new Set(
      puzzle.targets
        .filter((t) => t.id !== target.id)
        .flatMap((t) => t.path.map(key)),
    );
    if (cells.some((cell) => othersCells.has(key(cell)))) return false;
  }
  return traced.size === puzzle.targets.length;
}

// ---------------------------------------------------------------- dispatch

export type ProofResult = 'ok' | 'unknown_puzzle' | 'bad_proof';

/** Checks [proof] for [game] against the decoded puzzle [doc] (null when missing). */
export function checkProof(
  game: GameId,
  doc: Json | null,
  proof: unknown,
): ProofResult {
  if (!doc) return 'unknown_puzzle';
  switch (game) {
    case 'zip': {
      const puzzle = parseZipPuzzle(doc);
      if (!puzzle) return 'unknown_puzzle';
      return checkZipProof(puzzle, proof) ? 'ok' : 'bad_proof';
    }
    case 'sudoku': {
      const puzzle = parseSudokuPuzzle(doc);
      if (!puzzle) return 'unknown_puzzle';
      return checkSudokuProof(puzzle, proof) ? 'ok' : 'bad_proof';
    }
    case 'path_words': {
      const puzzle = parsePathWordsPuzzle(doc);
      if (!puzzle) return 'unknown_puzzle';
      return checkPathWordsProof(puzzle, proof) ? 'ok' : 'bad_proof';
    }
  }
}
