/**
 * `GET /api/today?day=yyyy-MM-dd`: today's boards and fastest clears for the
 * landing page, answered from Cloudflare's cache where possible so visits
 * don't spend the app's Firestore reads (the Spark plan's 50,000 a day).
 *
 * A cache miss costs per game 1 read for the puzzle (itself cached for 6
 * hours), up to 3 for the fastest entries and 1 for the count. Only days live
 * somewhere are accepted, so at most three cache keys exist at a time.
 */

import { isDayLive } from '../../leaderboard/src/days';
import { GAMES, type GameId } from '../../leaderboard/src/limits';
import { countClears, readPuzzle, readTopEntries, type Fetch } from './firestore_reads';
import {
  boardFor,
  difficultyOf,
  topEntry,
  type Board,
  type GameToday,
  type Today,
  type TopEntry,
} from './today';

export type Deps = {
  fetch: Fetch;
  /** `caches.default` on Cloudflare; null skips caching. */
  cache: Cache | null;
  now: () => Date;
  waitUntil: (promise: Promise<unknown>) => void;
};

/** How many of today's fastest clears each game shows. */
export const TOP_LIMIT = 3;

/** Seconds a browser keeps an answer. */
export const BROWSER_MAX_AGE = 60;

/** Seconds the edge keeps a full answer, and one where a read failed. */
export const EDGE_MAX_AGE = 300;
export const PARTIAL_EDGE_MAX_AGE = 30;

/** Seconds the edge keeps a puzzle; a live day's puzzle doesn't change. */
export const PUZZLE_MAX_AGE = 6 * 60 * 60;

type Puzzle = { difficulty: string | null; board: Board | null };

function json(body: unknown, status: number, cacheControl: string): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': cacheControl,
      'x-content-type-options': 'nosniff',
    },
  });
}

async function cached(deps: Deps, key: string): Promise<Response | undefined> {
  if (!deps.cache) return undefined;
  try {
    return await deps.cache.match(key);
  } catch (error) {
    console.error('cache match failed', error);
    return undefined;
  }
}

/** Stores [body] at the edge for [maxAge] seconds without delaying the answer. */
function store(deps: Deps, key: string, body: unknown, maxAge: number): void {
  if (!deps.cache) return;
  const copy = json(body, 200, `public, max-age=${maxAge}`);
  deps.waitUntil(
    deps.cache.put(key, copy).catch((error) => console.error('cache put failed', error)),
  );
}

async function puzzleFor(deps: Deps, origin: string, game: GameId, day: string): Promise<Puzzle> {
  const key = `${origin}/api/today/puzzle/${game}/${day}`;
  const hit = await cached(deps, key);
  if (hit) return (await hit.json()) as Puzzle;
  const data = await readPuzzle(deps.fetch, game, day);
  const puzzle: Puzzle = data
    ? { difficulty: difficultyOf(data), board: boardFor(game, data) }
    : { difficulty: null, board: null };
  // A puzzle that isn't there yet may be generated any minute: don't keep that.
  if (puzzle.board) store(deps, key, puzzle, PUZZLE_MAX_AGE);
  return puzzle;
}

async function gameToday(
  deps: Deps,
  origin: string,
  game: GameId,
  day: string,
): Promise<{ today: GameToday; complete: boolean }> {
  const [puzzle, top, clears] = await Promise.allSettled([
    puzzleFor(deps, origin, game, day),
    readTopEntries(deps.fetch, game, day, TOP_LIMIT),
    countClears(deps.fetch, game, day),
  ]);
  for (const result of [puzzle, top, clears]) {
    if (result.status === 'rejected') console.error(`today ${game} ${day}`, result.reason);
  }
  const { difficulty, board } =
    puzzle.status === 'fulfilled' ? puzzle.value : { difficulty: null, board: null };
  return {
    today: {
      difficulty,
      board,
      clears: clears.status === 'fulfilled' ? clears.value : null,
      top:
        top.status === 'fulfilled'
          ? top.value.map((entry) => topEntry(game, entry)).filter((e): e is TopEntry => e !== null)
          : null,
    },
    complete: [puzzle, top, clears].every((result) => result.status === 'fulfilled'),
  };
}

export async function handleToday(request: Request, deps: Deps): Promise<Response> {
  const url = new URL(request.url);
  const day = url.searchParams.get('day') ?? '';
  if (!isDayLive(day, deps.now())) return json({ error: 'day_not_live' }, 400, 'no-store');

  const browserCache = `public, max-age=${BROWSER_MAX_AGE}`;
  const key = `${url.origin}/api/today?day=${day}`;
  const hit = await cached(deps, key);
  if (hit) {
    const res = new Response(hit.body, hit);
    res.headers.set('cache-control', browserCache);
    res.headers.set('x-winklo-cache', 'hit');
    return res;
  }

  const results = await Promise.all(GAMES.map((game) => gameToday(deps, url.origin, game, day)));
  const games = Object.fromEntries(GAMES.map((game, i) => [game, results[i].today])) as Record<
    GameId,
    GameToday
  >;
  if (results.every(({ today }) => today.board === null && today.top === null)) {
    return json({ error: 'unavailable' }, 502, 'no-store');
  }
  const body: Today = { day, updatedAt: deps.now().toISOString(), games };
  const complete = results.every((result) => result.complete);
  store(deps, key, body, complete ? EDGE_MAX_AGE : PARTIAL_EDGE_MAX_AGE);
  const res = json(body, 200, browserCache);
  res.headers.set('x-winklo-cache', 'miss');
  return res;
}
