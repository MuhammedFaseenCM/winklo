/**
 * Pure pieces of the level-clear route: reading the body, finding the
 * published level, and merging a run into the player's server-side bests.
 */

import { cleanIdentity, type Identity } from './identity';
import { LEVEL_GAMES, MAX_SECONDS, type LevelGameId } from './limits';
import { parseZipPuzzle, type ZipPuzzle } from './proofs';

export { LEVEL_GAMES, type LevelGameId };

export type LevelClear = {
  gameId: LevelGameId;
  levelId: string;
  worldOrder: number;
  timeSeconds: number;
  usedHints: boolean;
  proof: unknown;
  identity: Identity | null;
};

export type LevelRecord = { stars: number; bestSeconds: number };

const LEVEL_ID_PATTERN = /^zip_(\d+)_(\d+)$/;

function isLevelGame(value: unknown): value is LevelGameId {
  return typeof value === 'string' && (LEVEL_GAMES as readonly string[]).includes(value);
}

/** The level clear in [body], or null when any field is missing or of the wrong type. */
export function parseLevelClearBody(body: unknown): LevelClear | null {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return null;
  const b = body as Record<string, unknown>;
  if (!isLevelGame(b.gameId)) return null;
  if (typeof b.levelId !== 'string') return null;
  const match = LEVEL_ID_PATTERN.exec(b.levelId);
  if (!match) return null;
  const worldOrder = Number(match[1]);
  if (!Number.isSafeInteger(worldOrder)) return null;
  const seconds = b.timeSeconds;
  if (typeof seconds !== 'number' || !Number.isInteger(seconds)) return null;
  if (seconds < 1 || seconds > MAX_SECONDS) return null;
  if (typeof b.usedHints !== 'boolean') return null;
  if (b.displayName !== undefined && b.displayName !== null && typeof b.displayName !== 'string') {
    return null;
  }
  return {
    gameId: b.gameId,
    levelId: b.levelId,
    worldOrder,
    timeSeconds: seconds,
    usedHints: b.usedHints,
    proof: b.proof,
    identity: cleanIdentity(b),
  };
}

/**
 * The level [levelId] of a published world doc, or null when the doc is
 * missing or unpublished, the level isn't in it, or its board doesn't parse.
 */
export function findLevel(
  worldDoc: Record<string, unknown> | null,
  levelId: string,
): { puzzle: ZipPuzzle; targetSeconds: number | null } | null {
  if (!worldDoc || worldDoc.published !== true) return null;
  const levels = worldDoc.levels;
  if (!Array.isArray(levels)) return null;
  const level = levels.find(
    (l): l is Record<string, unknown> =>
      !!l && typeof l === 'object' && !Array.isArray(l) && (l as { id?: unknown }).id === levelId,
  );
  if (!level) return null;
  const puzzle = parseZipPuzzle(level);
  if (!puzzle) return null;
  const target = level.targetSeconds;
  return { puzzle, targetSeconds: typeof target === 'number' ? target : null };
}

function isValidRecord(value: unknown): value is LevelRecord {
  if (!value || typeof value !== 'object') return false;
  const { stars, bestSeconds } = value as Record<string, unknown>;
  return (
    typeof stars === 'number' &&
    Number.isInteger(stars) &&
    stars >= 1 &&
    stars <= 3 &&
    typeof bestSeconds === 'number' &&
    Number.isInteger(bestSeconds) &&
    bestSeconds >= 1
  );
}

/**
 * [run] folded into [records]: the higher stars and the lower time, each kept
 * separately. A stored entry that isn't valid counts as absent.
 */
export function mergeLevelRecord(
  records: Record<string, LevelRecord>,
  levelId: string,
  run: LevelRecord,
): { records: Record<string, LevelRecord>; improved: boolean } {
  const stored = Object.hasOwn(records, levelId) ? records[levelId] : undefined;
  if (!isValidRecord(stored)) {
    return { records: { ...records, [levelId]: { ...run } }, improved: true };
  }
  const merged = {
    stars: Math.max(stored.stars, run.stars),
    bestSeconds: Math.min(stored.bestSeconds, run.bestSeconds),
  };
  if (merged.stars === stored.stars && merged.bestSeconds === stored.bestSeconds) {
    return { records, improved: false };
  }
  return { records: { ...records, [levelId]: merged }, improved: true };
}

/** The board row's figures, always recomputed from [records]. */
export function levelBoardTotals(records: Record<string, LevelRecord>): {
  stars: number;
  levelsCleared: number;
  timeSeconds: number;
} {
  let stars = 0;
  let levelsCleared = 0;
  let timeSeconds = 0;
  for (const record of Object.values(records)) {
    if (!isValidRecord(record)) continue;
    stars += record.stars;
    levelsCleared += 1;
    timeSeconds += record.bestSeconds;
  }
  return { stars, levelsCleared, timeSeconds };
}
