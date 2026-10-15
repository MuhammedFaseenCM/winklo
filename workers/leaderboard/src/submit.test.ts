import { afterEach, describe, expect, it, vi } from 'vitest';
import { encodeFields } from './firestore';
import { boardPaths, cappedStreak, handleSubmit, parseSubmitBody } from './submit';

const DOCS = 'projects/p/databases/(default)/documents';

// 3×3 Zip board solved by a serpentine path.
const serpentine = [
  [0, 0], [0, 1], [0, 2],
  [1, 2], [1, 1], [1, 0],
  [2, 0], [2, 1], [2, 2],
];
const zipPuzzle = {
  size: 3,
  numbers: { '0,0': 1, '1,1': 2, '2,2': 3 },
  walls: [],
  solution: serpentine.map(([row, col]) => ({ row, col })),
};

const sudokuSolution = [
  1, 2, 3, 4, 5, 6, 4, 5, 6, 1, 2, 3, 2, 3, 1, 5, 6, 4,
  5, 6, 4, 2, 3, 1, 3, 1, 2, 6, 4, 5, 6, 4, 5, 3, 1, 2,
];

function body(overrides: Record<string, unknown> = {}) {
  return {
    gameId: 'zip',
    dayId: '2026-10-15',
    timeSeconds: 42,
    usedHints: false,
    hadMistakes: false,
    currentStreak: 4,
    displayName: '  Ada  ',
    photoUrl: 'https://example.com/a.jpg',
    avatarId: 'preset_01',
    proof: { path: serpentine },
    ...overrides,
  };
}

type StoredFake = { fields: Record<string, unknown>; updateTime: string };

/** A fake Firestore REST API holding [docs] by full name. */
function fakeFirestore(
  docs: Record<string, StoredFake>,
  opts: { contentions?: number; failGet?: boolean } = {},
) {
  let contentions = opts.contentions ?? 0;
  const commits: Array<{ writes: Array<Record<string, unknown>> }> = [];
  const gets: string[][] = [];
  const fetchMock = vi.fn(async (input: string, init?: RequestInit) => {
    const url = String(input);
    const payload = JSON.parse(String(init?.body ?? '{}'));
    if (url.endsWith(':batchGet')) {
      if (opts.failGet) return Response.json({ error: { status: 'UNAVAILABLE' } }, { status: 503 });
      gets.push(payload.documents);
      return Response.json(
        (payload.documents as string[]).map((name) =>
          docs[name]
            ? { found: { name, fields: docs[name].fields, updateTime: docs[name].updateTime } }
            : { missing: name },
        ),
      );
    }
    if (url.endsWith(':commit')) {
      commits.push(payload);
      if (contentions > 0) {
        contentions -= 1;
        return Response.json({ error: { status: 'FAILED_PRECONDITION' } }, { status: 400 });
      }
      return Response.json({ writeResults: [] });
    }
    return new Response('unexpected', { status: 500 });
  });
  vi.stubGlobal('fetch', fetchMock);
  return { commits, gets };
}

const deps = {
  projectId: 'p',
  getAccessToken: async () => 't',
  now: () => new Date('2026-10-15T08:00:00Z'),
};

const zipDoc = { [`${DOCS}/zip_levels/daily_20261015`]: { fields: encodeFields(zipPuzzle), updateTime: 'P' } };

afterEach(() => vi.unstubAllGlobals());

describe('parseSubmitBody', () => {
  it('accepts a well-formed body and cleans the identity', () => {
    const parsed = parseSubmitBody(body())!;
    expect(parsed.gameId).toBe('zip');
    expect(parsed.identity).toEqual({ displayName: 'Ada', photoUrl: null, avatarId: 'preset_01' });
  });

  it('keeps the stored identity when the app sends no name', () => {
    expect(parseSubmitBody(body({ displayName: null }))!.identity).toBeNull();
  });

  it.each([
    ['unknown game', { gameId: 'word_match' }],
    ['bad day', { dayId: '2026-02-30' }],
    ['compact day', { dayId: '20261015' }],
    ['fractional time', { timeSeconds: 41.5 }],
    ['zero time', { timeSeconds: 0 }],
    ['over a day', { timeSeconds: 86_401 }],
    ['time as string', { timeSeconds: '42' }],
    ['flags missing', { usedHints: undefined }],
    ['negative streak', { currentStreak: -1 }],
    ['name not a string', { displayName: 7 }],
    ['no proof', { proof: undefined }],
    ['proof not an object', { proof: [1, 2] }],
  ])('refuses %s', (_, overrides) => {
    expect(parseSubmitBody(body(overrides))).toBeNull();
  });

  it('refuses non-objects', () => {
    expect(parseSubmitBody(null)).toBeNull();
    expect(parseSubmitBody([])).toBeNull();
  });
});

describe('boardPaths', () => {
  it('names the release boards and the ISO week', () => {
    const paths = boardPaths('p', 'u1', 'zip', '2026-10-15');
    expect(paths.puzzles).toEqual([`${DOCS}/zip_levels/daily_20261015`]);
    expect(paths.streak).toBe(`${DOCS}/users/u1/game_streaks/zip`);
    expect(paths.daily).toBe(`${DOCS}/leaderboards/zip/daily/2026-10-15/entries/u1`);
    expect(paths.allTime).toBe(`${DOCS}/leaderboards/zip/all_time/u1`);
    expect(paths.weekly).toBe(`${DOCS}/leaderboards/zip/weekly/2026-W42/entries/u1`);
  });

  it('also tries the older Sudoku id', () => {
    expect(boardPaths('p', 'u1', 'sudoku', '2026-10-15').puzzles).toEqual([
      `${DOCS}/sudoku_levels/daily_20261015`,
      `${DOCS}/sudoku_levels/sudoku_20261015`,
    ]);
  });
});

describe('cappedStreak', () => {
  it('allows one more than the synced streak', () => {
    const doc = { data: { current: 3 }, updateTime: 'T' };
    expect(cappedStreak(9, doc)).toBe(4);
    expect(cappedStreak(2, doc)).toBe(2);
    expect(cappedStreak(9, null)).toBe(1);
    expect(cappedStreak(9, { data: { current: 'x' }, updateTime: 'T' })).toBe(1);
  });
});

describe('handleSubmit', () => {
  it('refuses a day that is not live', async () => {
    fakeFirestore(zipDoc);
    const res = await handleSubmit(deps, 'u1', body({ dayId: '2026-10-17' }));
    expect(res).toEqual({ status: 422, body: { error: 'not_live' } });
  });

  it('refuses a time under the game minimum', async () => {
    fakeFirestore(zipDoc);
    expect(await handleSubmit(deps, 'u1', body({ timeSeconds: 9 }))).toEqual({
      status: 422,
      body: { error: 'too_fast' },
    });
    expect(
      await handleSubmit(deps, 'u1', body({ gameId: 'sudoku', timeSeconds: 14 })),
    ).toEqual({ status: 422, body: { error: 'too_fast' } });
  });

  it('refuses a malformed body or uid', async () => {
    fakeFirestore(zipDoc);
    expect((await handleSubmit(deps, 'u1', body({ timeSeconds: 'x' }))).status).toBe(400);
    expect((await handleSubmit(deps, '../users/x', body())).status).toBe(400);
  });

  it('refuses a day without a puzzle', async () => {
    fakeFirestore({});
    expect(await handleSubmit(deps, 'u1', body())).toEqual({
      status: 422,
      body: { error: 'unknown_puzzle' },
    });
  });

  it('refuses a proof that does not solve the puzzle', async () => {
    const fake = fakeFirestore(zipDoc);
    const res = await handleSubmit(deps, 'u1', body({ proof: { path: serpentine.slice(1) } }));
    expect(res).toEqual({ status: 422, body: { error: 'bad_proof' } });
    expect(fake.commits).toHaveLength(0);
  });

  it('writes the daily, all-time and weekly entries in one commit', async () => {
    const fake = fakeFirestore({
      ...zipDoc,
      [`${DOCS}/users/u1/game_streaks/zip`]: {
        fields: encodeFields({ current: 2 }),
        updateTime: 'S',
      },
      [`${DOCS}/leaderboards/zip/all_time/u1`]: {
        fields: encodeFields({ timeSeconds: 30, displayName: 'Old' }),
        updateTime: 'A1',
      },
    });

    const res = await handleSubmit(deps, 'u1', body());

    expect(res).toEqual({ status: 200, body: { accepted: true, improved: true, rank: null } });
    expect(fake.gets).toHaveLength(1);
    expect(fake.commits).toHaveLength(1);
    const writes = fake.commits[0].writes as Array<{
      update: { name: string; fields: Record<string, unknown> };
      updateMask: { fieldPaths: string[] };
      currentDocument: unknown;
      updateTransforms?: unknown;
    }>;
    expect(writes.map((w) => w.update.name)).toEqual([
      `${DOCS}/leaderboards/zip/daily/2026-10-15/entries/u1`,
      `${DOCS}/leaderboards/zip/all_time/u1`,
      `${DOCS}/leaderboards/zip/weekly/2026-W42/entries/u1`,
    ]);
    const [daily, allTime, weekly] = writes;
    expect(daily.currentDocument).toEqual({ exists: false });
    expect(daily.update.fields.timeSeconds).toEqual({ integerValue: '42' });
    // Capped at the synced streak (2) + 1.
    expect(daily.update.fields.currentStreak).toEqual({ integerValue: '3' });
    expect(daily.update.fields.displayName).toEqual({ stringValue: 'Ada' });
    expect(daily.update.fields.photoUrl).toEqual({ nullValue: null });
    // All-time already has a faster time: only the streak and identity move.
    expect(allTime.currentDocument).toEqual({ updateTime: 'A1' });
    expect(allTime.updateMask.fieldPaths).not.toContain('timeSeconds');
    expect(allTime.updateTransforms).toBeUndefined();
    expect(weekly.update.fields.daysCleared).toEqual({ integerValue: '1' });
    expect(weekly.update.fields.totalSeconds).toEqual({ integerValue: '42' });
  });

  it('checks Sudoku against the older id too', async () => {
    const fake = fakeFirestore({
      [`${DOCS}/sudoku_levels/sudoku_20261015`]: {
        fields: encodeFields({ given: sudokuSolution, solution: sudokuSolution }),
        updateTime: 'P',
      },
    });
    const res = await handleSubmit(
      deps,
      'u1',
      body({ gameId: 'sudoku', proof: { grid: sudokuSolution } }),
    );
    expect(res.status).toBe(200);
    expect(fake.commits).toHaveLength(1);
  });

  it('reads again and retries once when another write got in first', async () => {
    const fake = fakeFirestore(zipDoc, { contentions: 1 });
    const res = await handleSubmit(deps, 'u1', body());
    expect(res.status).toBe(200);
    expect(fake.commits).toHaveLength(2);
    expect(fake.gets).toHaveLength(2);
    // The retry only re-reads the three entries.
    expect(fake.gets[1]).toHaveLength(3);
  });

  it('gives up with a 503 after a second contention', async () => {
    const fake = fakeFirestore(zipDoc, { contentions: 2 });
    expect(await handleSubmit(deps, 'u1', body())).toEqual({
      status: 503,
      body: { error: 'busy' },
    });
    expect(fake.commits).toHaveLength(2);
  });

  it('answers 503 when Firestore is down, so the app falls back', async () => {
    fakeFirestore(zipDoc, { failGet: true });
    expect(await handleSubmit(deps, 'u1', body())).toEqual({
      status: 503,
      body: { error: 'unavailable' },
    });
  });
});
