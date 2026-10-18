/**
 * The landing page's Firestore reads, over the REST API without credentials:
 * the rules already make the daily puzzles (once live) and the leaderboards
 * public, and nothing else is readable this way.
 */

import { decodeFields, decodeValue, documentsBase } from '../../leaderboard/src/firestore';
import { LEADERBOARD_ROOT, MIN_SECONDS, PUZZLE_COLLECTIONS, type GameId } from '../../leaderboard/src/limits';
import { compactDateId } from '../../leaderboard/src/days';
import { ENTRY_FIELDS, PUZZLE_FIELDS } from './today';

export const PROJECT_ID = 'brain-zip-app';

const DOCUMENTS = `https://firestore.googleapis.com/v1/${documentsBase(PROJECT_ID)}`;

export type Fetch = (input: string, init?: RequestInit) => Promise<Response>;

export class FirestoreReadError extends Error {
  constructor(what: string, status: number) {
    super(`Firestore ${what} failed with HTTP ${status}`);
    this.name = 'FirestoreReadError';
  }
}

/** Today's puzzle doc for [game], or null when it doesn't exist (yet). */
export async function readPuzzle(
  fetchFn: Fetch,
  game: GameId,
  dayId: string,
): Promise<Record<string, unknown> | null> {
  const mask = PUZZLE_FIELDS[game].map((f) => `mask.fieldPaths=${f}`).join('&');
  const url = `${DOCUMENTS}/${PUZZLE_COLLECTIONS[game]}/daily_${compactDateId(dayId)}?${mask}`;
  const res = await fetchFn(url);
  if (res.status === 404) return null;
  if (!res.ok) throw new FirestoreReadError(`${game} puzzle read`, res.status);
  const doc = (await res.json()) as { fields?: Record<string, unknown> };
  return decodeFields(doc.fields);
}

function dailyEntries(game: GameId, dayId: string): string {
  return `${DOCUMENTS}/${LEADERBOARD_ROOT}/${game}/daily/${dayId}`;
}

/** Leaves out times under the game's minimum, as the leaderboard Worker does. */
function fairTimes(game: GameId) {
  return {
    fieldFilter: {
      field: { fieldPath: 'timeSeconds' },
      op: 'GREATER_THAN_OR_EQUAL',
      value: { integerValue: String(MIN_SECONDS[game]) },
    },
  };
}

/** The fastest [limit] fair entries on [game]'s board for [dayId]. */
export async function readTopEntries(
  fetchFn: Fetch,
  game: GameId,
  dayId: string,
  limit: number,
): Promise<Record<string, unknown>[]> {
  const res = await fetchFn(`${dailyEntries(game, dayId)}:runQuery`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'entries' }],
        select: { fields: ENTRY_FIELDS.map((fieldPath) => ({ fieldPath })) },
        where: fairTimes(game),
        orderBy: [{ field: { fieldPath: 'timeSeconds' }, direction: 'ASCENDING' }],
        limit,
      },
    }),
  });
  if (!res.ok) throw new FirestoreReadError(`${game} leaderboard query`, res.status);
  const rows = (await res.json()) as { document?: { fields?: Record<string, unknown> } }[];
  return rows.filter((row) => row.document).map((row) => decodeFields(row.document!.fields));
}

/** How many players have a fair time on [game]'s board for [dayId] (1 read per 1,000). */
export async function countClears(fetchFn: Fetch, game: GameId, dayId: string): Promise<number> {
  const res = await fetchFn(`${dailyEntries(game, dayId)}:runAggregationQuery`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      structuredAggregationQuery: {
        structuredQuery: { from: [{ collectionId: 'entries' }], where: fairTimes(game) },
        aggregations: [{ alias: 'clears', count: {} }],
      },
    }),
  });
  if (!res.ok) throw new FirestoreReadError(`${game} leaderboard count`, res.status);
  const rows = (await res.json()) as { result?: { aggregateFields?: Record<string, unknown> } }[];
  const count = decodeValue(rows[0]?.result?.aggregateFields?.clears);
  if (!Number.isInteger(count)) throw new FirestoreReadError(`${game} leaderboard count`, 200);
  return count as number;
}
