/**
 * `POST /v1/submit`: checks one clear and writes it to the release boards.
 *
 * Checks, in order: the body's shape (`bad_request`), the day is live
 * (`not_live`), the time is at least the game's minimum (`too_fast`), the
 * day's puzzle exists (`unknown_puzzle`) and the proof solves it
 * (`bad_proof`). Then one commit writes the daily, all-time and weekly
 * entries, each guarded by the `updateTime` it was read at; if another write
 * got in between, it reads again and retries once.
 */

import { compactDateId, isDayLive, isoWeekId, parseDayId } from './days';
import {
  changesNothing,
  planEntryWrite,
  planWeeklyWrite,
  toCommitWrite,
  type Submission,
} from './entries';
import {
  ContentionError,
  batchGet,
  commit,
  documentsBase,
  type StoredDoc,
} from './firestore';
import { cleanIdentity } from './identity';
import {
  LEADERBOARD_ROOT,
  MAX_SECONDS,
  MIN_SECONDS,
  PUZZLE_COLLECTIONS,
  isGameId,
  type GameId,
} from './limits';
import { checkProof } from './proofs';

export type SubmitErrorCode =
  | 'bad_request'
  | 'not_live'
  | 'too_fast'
  | 'bad_proof'
  | 'unknown_puzzle';

export type SubmitResponse =
  | { status: 200; body: { accepted: true; improved: boolean; rank: null } }
  | { status: 400 | 422; body: { error: SubmitErrorCode } }
  | { status: 503; body: { error: 'busy' | 'unavailable' } };

export type ParsedSubmission = Submission & {
  gameId: GameId;
  dayId: string;
  proof: unknown;
};

/** A stored streak can't run past this; anything bigger is junk. */
const MAX_STREAK = 100_000;

/** Firebase uids are short alphanumeric strings; anything else would break the doc paths. */
const UID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

function isWholeNumber(value: unknown, min: number, max: number): value is number {
  return typeof value === 'number' && Number.isInteger(value) && value >= min && value <= max;
}

/** The submission in [body], or null when any field is missing or of the wrong type. */
export function parseSubmitBody(body: unknown): ParsedSubmission | null {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return null;
  const b = body as Record<string, unknown>;
  if (!isGameId(b.gameId)) return null;
  if (typeof b.dayId !== 'string' || !parseDayId(b.dayId)) return null;
  if (!isWholeNumber(b.timeSeconds, 1, MAX_SECONDS)) return null;
  if (typeof b.usedHints !== 'boolean' || typeof b.hadMistakes !== 'boolean') return null;
  if (!isWholeNumber(b.currentStreak, 0, MAX_STREAK)) return null;
  if (b.displayName !== undefined && b.displayName !== null && typeof b.displayName !== 'string') {
    return null;
  }
  if (!b.proof || typeof b.proof !== 'object' || Array.isArray(b.proof)) return null;
  return {
    gameId: b.gameId,
    dayId: b.dayId,
    timeSeconds: b.timeSeconds,
    usedHints: b.usedHints,
    hadMistakes: b.hadMistakes,
    currentStreak: b.currentStreak,
    identity: cleanIdentity(b),
    proof: b.proof,
  };
}

export type SubmitDeps = {
  projectId: string;
  getAccessToken: () => Promise<string>;
  now: () => Date;
};

export type BoardPaths = {
  puzzles: string[];
  streak: string;
  daily: string;
  allTime: string;
  weekly: string;
};

/** Full resource names of every doc one submission reads or writes. */
export function boardPaths(
  projectId: string,
  uid: string,
  gameId: GameId,
  dayId: string,
): BoardPaths {
  const base = documentsBase(projectId);
  const date = compactDateId(dayId);
  const collection = PUZZLE_COLLECTIONS[gameId];
  const puzzles = [`${base}/${collection}/daily_${date}`];
  // The app's Sudoku loader falls back to the older `sudoku_YYYYMMDD` id.
  if (gameId === 'sudoku') puzzles.push(`${base}/${collection}/sudoku_${date}`);
  const game = `${base}/${LEADERBOARD_ROOT}/${gameId}`;
  return {
    puzzles,
    streak: `${base}/users/${uid}/game_streaks/${gameId}`,
    daily: `${game}/daily/${dayId}/entries/${uid}`,
    allTime: `${game}/all_time/${uid}`,
    weekly: `${game}/weekly/${isoWeekId(dayId)}/entries/${uid}`,
  };
}

/** The streak the player may claim: at most one more than their synced streak. */
export function cappedStreak(claimed: number, streakDoc: StoredDoc | null): number {
  const current = streakDoc?.data.current;
  const synced = isWholeNumber(current, 0, MAX_STREAK) ? current : 0;
  return Math.min(claimed, synced + 1);
}

function fail(status: 400 | 422, error: SubmitErrorCode): SubmitResponse {
  return { status, body: { error } };
}

export async function handleSubmit(
  deps: SubmitDeps,
  uid: string,
  rawBody: unknown,
): Promise<SubmitResponse> {
  if (!UID_PATTERN.test(uid)) return fail(400, 'bad_request');
  const parsed = parseSubmitBody(rawBody);
  if (!parsed) return fail(400, 'bad_request');
  if (!isDayLive(parsed.dayId, deps.now())) return fail(422, 'not_live');
  if (parsed.timeSeconds < MIN_SECONDS[parsed.gameId]) return fail(422, 'too_fast');

  const paths = boardPaths(deps.projectId, uid, parsed.gameId, parsed.dayId);
  const entryNames = [paths.daily, paths.allTime, paths.weekly];

  try {
    const accessToken = await deps.getAccessToken();
    const docs = await batchGet({
      projectId: deps.projectId,
      accessToken,
      names: [...paths.puzzles, paths.streak, ...entryNames],
    });

    const puzzle = paths.puzzles.map((name) => docs.get(name)).find((doc) => doc) ?? null;
    const proof = checkProof(parsed.gameId, puzzle?.data ?? null, parsed.proof);
    if (proof !== 'ok') return fail(422, proof);

    const submission: Submission = {
      ...parsed,
      currentStreak: cappedStreak(parsed.currentStreak, docs.get(paths.streak) ?? null),
    };

    const minSeconds = MIN_SECONDS[parsed.gameId];
    let entries = docs;
    for (let attempt = 0; ; attempt++) {
      const stored = (name: string) => entries.get(name) ?? null;
      const daily = planEntryWrite(stored(paths.daily), submission, minSeconds);
      const allTime = planEntryWrite(stored(paths.allTime), submission, minSeconds);
      const weekly = planWeeklyWrite(
        stored(paths.weekly),
        parsed.dayId,
        parsed.timeSeconds,
        submission.identity,
      );
      const writes = (
        [
          [paths.daily, daily],
          [paths.allTime, allTime],
          [paths.weekly, weekly],
        ] as const
      )
        .filter(([name, plan]) => !changesNothing(stored(name), plan))
        .map(([name, plan]) => toCommitWrite(name, plan));
      try {
        if (writes.length > 0) {
          await commit({ projectId: deps.projectId, accessToken, writes });
        }
        return {
          status: 200,
          body: { accepted: true, improved: daily.improved, rank: null },
        };
      } catch (e) {
        if (!(e instanceof ContentionError)) throw e;
        if (attempt >= 1) return { status: 503, body: { error: 'busy' } };
        entries = await batchGet({ projectId: deps.projectId, accessToken, names: entryNames });
      }
    }
  } catch (e) {
    console.error('leaderboard_submit_failed', e instanceof Error ? e.message : e);
    return { status: 503, body: { error: 'unavailable' } };
  }
}
