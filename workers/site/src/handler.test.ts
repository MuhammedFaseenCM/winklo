import { beforeEach, describe, expect, it, vi } from 'vitest';
import { handleToday, type Deps } from './handler';
import type { Today } from './today';

const NOW = new Date('2026-10-16T06:00:00Z');
const ORIGIN = 'https://winklo.pages.dev';

function int(n: number) {
  return { integerValue: String(n) };
}

function str(s: string) {
  return { stringValue: s };
}

function arr(values: unknown[]) {
  return { arrayValue: { values } };
}

const PUZZLES: Record<string, unknown> = {
  zip_levels: {
    size: int(2),
    difficulty: str('hard'),
    numbers: { mapValue: { fields: { '0,0': int(1), '1,0': int(2) } } },
    walls: arr([]),
  },
  sudoku_levels: {
    size: int(2),
    boxRows: int(1),
    boxCols: int(2),
    difficulty: str('hard'),
    given: arr([int(1), int(0), int(0), int(1)]),
  },
  path_words_levels: {
    size: int(2),
    difficulty: str('hard'),
    letters: arr([str('a'), str('b'), str(''), str('c')]),
    targets: arr([{ mapValue: { fields: { word: str('abc') } } }]),
  },
};

function entry(name: string, time: number) {
  return {
    document: {
      fields: {
        displayName: str(name),
        timeSeconds: int(time),
        usedHints: { booleanValue: false },
        currentStreak: int(3),
      },
    },
  };
}

type Route = (url: string, init?: RequestInit) => Response | Promise<Response>;

function firestore(overrides: Partial<Record<'puzzle' | 'query' | 'count', Route>> = {}) {
  return vi.fn(async (url: string, init?: RequestInit) => {
    if (url.endsWith(':runQuery')) {
      if (overrides.query) return overrides.query(url, init);
      return Response.json([entry('Arun Kumar', 48), entry('Karna', 61)]);
    }
    if (url.endsWith(':runAggregationQuery')) {
      if (overrides.count) return overrides.count(url, init);
      return Response.json([{ result: { aggregateFields: { clears: int(7) } } }]);
    }
    if (overrides.puzzle) return overrides.puzzle(url, init);
    const collection = Object.keys(PUZZLES).find((c) => url.includes(`/${c}/`));
    return collection
      ? Response.json({ fields: PUZZLES[collection] })
      : new Response('{}', { status: 404 });
  });
}

class MemoryCache {
  store = new Map<string, Response>();
  async match(key: string) {
    return this.store.get(key)?.clone();
  }
  async put(key: string, res: Response) {
    this.store.set(key, res.clone());
  }
}

let pending: Promise<unknown>[];

function deps(fetchFn: ReturnType<typeof firestore>, cache: MemoryCache | null = null): Deps {
  return {
    fetch: fetchFn,
    cache: cache as unknown as Cache | null,
    now: () => NOW,
    waitUntil: (p) => pending.push(p),
  };
}

function get(day: string | null) {
  const query = day === null ? '' : `?day=${day}`;
  return new Request(`${ORIGIN}/api/today${query}`);
}

beforeEach(() => {
  pending = [];
  vi.spyOn(console, 'error').mockImplementation(() => {});
});

describe('handleToday', () => {
  it('returns each game’s board, fastest clears and count', async () => {
    const res = await handleToday(get('2026-10-16'), deps(firestore()));
    expect(res.status).toBe(200);
    expect(res.headers.get('cache-control')).toBe('public, max-age=60');
    const body = (await res.json()) as Today;
    expect(body.day).toBe('2026-10-16');
    expect(body.updatedAt).toBe(NOW.toISOString());
    expect(body.games.zip).toEqual({
      difficulty: 'hard',
      board: { size: 2, numbers: [[0, 0, 1], [1, 0, 2]], walls: [] },
      clears: 7,
      top: [
        { name: 'Arun K.', timeSeconds: 48, hintFree: true, flawless: false, streak: 3 },
        { name: 'Karna', timeSeconds: 61, hintFree: true, flawless: false, streak: 3 },
      ],
    });
    expect(body.games.path_words.board).toEqual({ size: 2, letters: ['A', 'B', '', 'C'], words: 1 });
    expect(body.games.sudoku.board).toEqual({ size: 2, boxRows: 1, boxCols: 2, given: [1, 0, 0, 1] });
  });

  it('reads the day’s puzzle docs with a field mask that leaves out the solution', async () => {
    const fetchFn = firestore();
    await handleToday(get('2026-10-16'), deps(fetchFn));
    const urls = fetchFn.mock.calls.map(([url]) => url);
    const zip = urls.find((u) => u.includes('/zip_levels/daily_20261016?'));
    expect(zip).toBeDefined();
    expect(zip).toContain('mask.fieldPaths=numbers');
    expect(urls.join(' ')).not.toContain('solution');
  });

  it('asks Firestore for the fastest three fair times on the day’s board', async () => {
    const fetchFn = firestore();
    await handleToday(get('2026-10-16'), deps(fetchFn));
    const call = fetchFn.mock.calls.find(([url]) =>
      url.endsWith('/leaderboards/sudoku/daily/2026-10-16:runQuery'),
    );
    const query = JSON.parse(String(call?.[1]?.body)).structuredQuery;
    expect(query.limit).toBe(3);
    expect(query.where.fieldFilter.value).toEqual({ integerValue: '15' });
    expect(query.select.fields.map((f: { fieldPath: string }) => f.fieldPath)).not.toContain('photoUrl');
  });

  it('refuses a day that is not live anywhere', async () => {
    const fetchFn = firestore();
    // At 06:00 UTC, 17 October hasn't started at UTC+14 yet.
    for (const day of ['2026-10-14', '2026-10-17', '16-10-2026', '2026-02-30', null]) {
      const res = await handleToday(get(day), deps(fetchFn));
      expect(res.status).toBe(400);
    }
    expect(fetchFn).not.toHaveBeenCalled();
  });

  it('accepts yesterday while it is still live at UTC-12', async () => {
    const res = await handleToday(get('2026-10-15'), deps(firestore()));
    expect(res.status).toBe(200);
  });

  it('shows no board for a puzzle that is not there yet', async () => {
    const fetchFn = firestore({ puzzle: () => new Response('{}', { status: 404 }) });
    const body = (await (await handleToday(get('2026-10-16'), deps(fetchFn))).json()) as Today;
    expect(body.games.zip.board).toBeNull();
    expect(body.games.zip.top).toHaveLength(2);
  });

  it('keeps the other parts when the leaderboard fails', async () => {
    const fetchFn = firestore({
      query: () => new Response('quota', { status: 429 }),
      count: () => new Response('quota', { status: 429 }),
    });
    const res = await handleToday(get('2026-10-16'), deps(fetchFn));
    expect(res.status).toBe(200);
    const body = (await res.json()) as Today;
    expect(body.games.zip.board).not.toBeNull();
    expect(body.games.zip.top).toBeNull();
    expect(body.games.zip.clears).toBeNull();
  });

  it('fails as a whole only when nothing could be read', async () => {
    const down = () => new Response('down', { status: 503 });
    const fetchFn = firestore({ puzzle: down, query: down, count: down });
    const res = await handleToday(get('2026-10-16'), deps(fetchFn));
    expect(res.status).toBe(502);
    expect(res.headers.get('cache-control')).toBe('no-store');
  });

  describe('with a cache', () => {
    it('answers a repeat visit from the cache without reading Firestore', async () => {
      const cache = new MemoryCache();
      const fetchFn = firestore();
      const first = await handleToday(get('2026-10-16'), deps(fetchFn, cache));
      expect(first.headers.get('x-winklo-cache')).toBe('miss');
      await Promise.all(pending);
      fetchFn.mockClear();

      const second = await handleToday(get('2026-10-16&utm=x'), deps(fetchFn, cache));
      expect(second.headers.get('x-winklo-cache')).toBe('hit');
      expect(second.headers.get('cache-control')).toBe('public, max-age=60');
      expect(((await second.json()) as Today).games.zip.clears).toBe(7);
      expect(fetchFn).not.toHaveBeenCalled();
    });

    it('keeps a full answer for 5 minutes and a partial one for 30 seconds', async () => {
      const cache = new MemoryCache();
      await handleToday(get('2026-10-16'), deps(firestore(), cache));
      await Promise.all(pending);
      const full = cache.store.get(`${ORIGIN}/api/today?day=2026-10-16`);
      expect(full?.headers.get('cache-control')).toBe('public, max-age=300');

      const partial = new MemoryCache();
      const fetchFn = firestore({ count: () => new Response('', { status: 500 }) });
      await handleToday(get('2026-10-16'), deps(fetchFn, partial));
      await Promise.all(pending);
      const kept = partial.store.get(`${ORIGIN}/api/today?day=2026-10-16`);
      expect(kept?.headers.get('cache-control')).toBe('public, max-age=30');
    });

    it('keeps puzzles for 6 hours, so a leaderboard refresh skips their reads', async () => {
      const cache = new MemoryCache();
      await handleToday(get('2026-10-16'), deps(firestore(), cache));
      await Promise.all(pending);
      cache.store.delete(`${ORIGIN}/api/today?day=2026-10-16`);
      const fetchFn = firestore();
      await handleToday(get('2026-10-16'), deps(fetchFn, cache));
      const urls = fetchFn.mock.calls.map(([url]) => url);
      expect(urls.filter((u) => u.includes('_levels/'))).toEqual([]);
      expect(urls).toHaveLength(6);
      const puzzle = cache.store.get(`${ORIGIN}/api/today/puzzle/zip/2026-10-16`);
      expect(puzzle?.headers.get('cache-control')).toBe('public, max-age=21600');
    });

    it('does not keep a puzzle that is not there yet', async () => {
      const cache = new MemoryCache();
      const fetchFn = firestore({ puzzle: () => new Response('{}', { status: 404 }) });
      await handleToday(get('2026-10-16'), deps(fetchFn, cache));
      await Promise.all(pending);
      expect(cache.store.has(`${ORIGIN}/api/today/puzzle/zip/2026-10-16`)).toBe(false);
    });

    it('still answers when the cache throws', async () => {
      const broken = {
        match: async () => {
          throw new Error('no cache');
        },
        put: async () => {
          throw new Error('no cache');
        },
      };
      const res = await handleToday(get('2026-10-16'), {
        ...deps(firestore()),
        cache: broken as unknown as Cache,
      });
      await Promise.all(pending);
      expect(res.status).toBe(200);
    });
  });
});
