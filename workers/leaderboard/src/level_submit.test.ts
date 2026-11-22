import { afterEach, describe, expect, it, vi } from 'vitest';
import { encodeFields } from './firestore';
import { handleLevelClear } from './level_submit';

const DOCS = 'projects/p/databases/(default)/documents';
const WORLD = `${DOCS}/level_worlds/zip_1`;
const RECORDS = `${DOCS}/leaderboards/zip/level_records/u1`;
const ROW = `${DOCS}/leaderboards/zip/levels/u1`;

// 3x3 Zip board solved by a serpentine path.
const serpentine = [
  [0, 0], [0, 1], [0, 2],
  [1, 2], [1, 1], [1, 0],
  [2, 0], [2, 1], [2, 2],
];
const level = {
  id: 'zip_1_01',
  size: 3,
  numbers: { '0,0': 1, '1,1': 2, '2,2': 3 },
  walls: [],
  solution: serpentine.map(([row, col]) => ({ row, col })),
  targetSeconds: 30,
};

function body(overrides: Record<string, unknown> = {}) {
  return {
    gameId: 'zip',
    levelId: 'zip_1_01',
    timeSeconds: 12,
    usedHints: false,
    displayName: '  Ada  ',
    avatarId: 'preset_01',
    proof: { path: serpentine },
    ...overrides,
  };
}

type StoredFake = { fields: Record<string, unknown>; updateTime: string };

function world(published = true): Record<string, StoredFake> {
  return {
    [WORLD]: { fields: encodeFields({ published, levels: [level] }), updateTime: 'W' },
  };
}

/** A fake Firestore REST API holding [docs] by full name. */
function fakeFirestore(docs: Record<string, StoredFake>, opts: { contentions?: number } = {}) {
  let contentions = opts.contentions ?? 0;
  const commits: Array<{ writes: Array<Record<string, unknown>> }> = [];
  const gets: string[][] = [];
  vi.stubGlobal(
    'fetch',
    vi.fn(async (input: string, init?: RequestInit) => {
      const url = String(input);
      const payload = JSON.parse(String(init?.body ?? '{}'));
      if (url.endsWith(':batchGet')) {
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
    }),
  );
  return { commits, gets };
}

const deps = {
  projectId: 'p',
  getAccessToken: async () => 't',
  now: () => new Date('2026-10-15T08:00:00Z'),
};

type Write = {
  update: { name: string; fields: Record<string, unknown> };
  updateMask: { fieldPaths: string[] };
  currentDocument: unknown;
  updateTransforms?: unknown;
};

const touched = [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }];

afterEach(() => vi.unstubAllGlobals());

describe('handleLevelClear', () => {
  it('writes records and a row for a first clear', async () => {
    const fake = fakeFirestore(world());

    const res = await handleLevelClear(deps, 'u1', body({ stars: 1 }));

    expect(res).toEqual({ status: 200, body: { accepted: true, improved: true } });
    expect(fake.gets).toEqual([[WORLD, RECORDS, ROW]]);
    expect(fake.commits).toHaveLength(1);
    const [records, row] = fake.commits[0].writes as Write[];
    expect(records.update.name).toBe(RECORDS);
    expect(records.currentDocument).toEqual({ exists: false });
    expect(records.updateTransforms).toEqual(touched);
    expect(records.update.fields.levels).toEqual({
      mapValue: {
        fields: {
          zip_1_01: {
            mapValue: {
              fields: { stars: { integerValue: '3' }, bestSeconds: { integerValue: '12' } },
            },
          },
        },
      },
    });
    expect(row.update.name).toBe(ROW);
    expect(row.currentDocument).toEqual({ exists: false });
    expect(row.updateTransforms).toEqual(touched);
    expect(row.update.fields).toMatchObject({
      stars: { integerValue: '3' },
      levelsCleared: { integerValue: '1' },
      timeSeconds: { integerValue: '12' },
      displayName: { stringValue: 'Ada' },
      photoUrl: { nullValue: null },
      avatarId: { stringValue: 'preset_01' },
    });
  });

  it('gives two stars for a hinted clear and ignores a client stars field', async () => {
    const fake = fakeFirestore(world());

    await handleLevelClear(deps, 'u1', body({ usedHints: true, stars: 3 }));

    const row = (fake.commits[0].writes as Write[])[1];
    expect(row.update.fields.stars).toEqual({ integerValue: '2' });
  });

  it('leaves the stored identity alone when the body carries none', async () => {
    const fake = fakeFirestore(world());

    await handleLevelClear(deps, 'u1', body({ displayName: undefined }));

    const row = (fake.commits[0].writes as Write[])[1];
    expect(row.updateMask.fieldPaths).toEqual(['stars', 'levelsCleared', 'timeSeconds']);
  });

  it('makes no commit when the identical clear is sent again', async () => {
    const fake = fakeFirestore({
      ...world(),
      [RECORDS]: {
        fields: encodeFields({ levels: { zip_1_01: { stars: 3, bestSeconds: 12 } } }),
        updateTime: 'R1',
      },
      [ROW]: {
        fields: encodeFields({ stars: 3, levelsCleared: 1, timeSeconds: 12 }),
        updateTime: 'B1',
      },
    });

    const res = await handleLevelClear(deps, 'u1', body());

    expect(res).toEqual({ status: 200, body: { accepted: true, improved: false } });
    expect(fake.commits).toHaveLength(0);
  });

  it('makes no commit for a worse run', async () => {
    const fake = fakeFirestore({
      ...world(),
      [RECORDS]: {
        fields: encodeFields({ levels: { zip_1_01: { stars: 3, bestSeconds: 10 } } }),
        updateTime: 'R1',
      },
    });

    const res = await handleLevelClear(deps, 'u1', body({ timeSeconds: 20, usedHints: true }));

    expect(res).toEqual({ status: 200, body: { accepted: true, improved: false } });
    expect(fake.commits).toHaveLength(0);
  });

  it('keeps the stars but lowers the best time for a faster, hinted run', async () => {
    const fake = fakeFirestore({
      ...world(),
      [RECORDS]: {
        fields: encodeFields({
          levels: { zip_1_01: { stars: 3, bestSeconds: 25 }, zip_1_02: { stars: 2, bestSeconds: 40 } },
        }),
        updateTime: 'R1',
      },
      [ROW]: {
        fields: encodeFields({ stars: 5, levelsCleared: 2, timeSeconds: 65 }),
        updateTime: 'B1',
      },
    });

    const res = await handleLevelClear(deps, 'u1', body({ timeSeconds: 12, usedHints: true }));

    expect(res).toEqual({ status: 200, body: { accepted: true, improved: true } });
    const [records, row] = fake.commits[0].writes as Write[];
    expect(records.currentDocument).toEqual({ updateTime: 'R1' });
    expect(row.currentDocument).toEqual({ updateTime: 'B1' });
    const levels = (records.update.fields.levels as any).mapValue.fields;
    expect(levels.zip_1_01.mapValue.fields).toEqual({
      stars: { integerValue: '3' },
      bestSeconds: { integerValue: '12' },
    });
    expect(row.update.fields).toMatchObject({
      stars: { integerValue: '5' },
      levelsCleared: { integerValue: '2' },
      timeSeconds: { integerValue: '52' },
    });
  });

  it('422s not_live for an unpublished world, an unknown level or a missing world', async () => {
    fakeFirestore(world(false));
    expect(await handleLevelClear(deps, 'u1', body())).toEqual({
      status: 422,
      body: { error: 'not_live' },
    });

    fakeFirestore(world());
    expect(await handleLevelClear(deps, 'u1', body({ levelId: 'zip_1_09' }))).toEqual({
      status: 422,
      body: { error: 'not_live' },
    });

    fakeFirestore({});
    expect(await handleLevelClear(deps, 'u1', body())).toEqual({
      status: 422,
      body: { error: 'not_live' },
    });
  });

  it('422s bad_proof for a wrong path', async () => {
    const fake = fakeFirestore(world());
    const res = await handleLevelClear(deps, 'u1', body({ proof: { path: serpentine.slice().reverse() } }));
    expect(res).toEqual({ status: 422, body: { error: 'bad_proof' } });
    expect(fake.commits).toHaveLength(0);
  });

  it('422s a time outside the accepted range before reading anything', async () => {
    const fake = fakeFirestore(world());
    expect(await handleLevelClear(deps, 'u1', body({ timeSeconds: 0 }))).toEqual({
      status: 422,
      body: { error: 'too_fast' },
    });
    expect(await handleLevelClear(deps, 'u1', body({ timeSeconds: 86_401 }))).toEqual({
      status: 422,
      body: { error: 'too_slow' },
    });
    expect(fake.gets).toHaveLength(0);
  });

  it('400s a malformed body or uid', async () => {
    fakeFirestore(world());
    expect(await handleLevelClear(deps, 'u1', { gameId: 'zip' })).toEqual({
      status: 400,
      body: { error: 'bad_request' },
    });
    expect(await handleLevelClear(deps, 'a/b', body())).toEqual({
      status: 400,
      body: { error: 'bad_request' },
    });
  });

  it('reads again and succeeds after one contention', async () => {
    const fake = fakeFirestore(world(), { contentions: 1 });

    const res = await handleLevelClear(deps, 'u1', body());

    expect(res).toEqual({ status: 200, body: { accepted: true, improved: true } });
    expect(fake.commits).toHaveLength(2);
    expect(fake.gets).toEqual([[WORLD, RECORDS, ROW], [RECORDS, ROW]]);
  });

  it('503s busy after two contentions', async () => {
    const fake = fakeFirestore(world(), { contentions: 2 });

    const res = await handleLevelClear(deps, 'u1', body());

    expect(res).toEqual({ status: 503, body: { error: 'busy' } });
    expect(fake.commits).toHaveLength(2);
  });

  it('503s unavailable when Firestore fails', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response('x', { status: 500 })));
    const log = vi.spyOn(console, 'error').mockImplementation(() => {});
    const res = await handleLevelClear(deps, 'u1', body());
    expect(res).toEqual({ status: 503, body: { error: 'unavailable' } });
    log.mockRestore();
  });
});

describe('handleLevelClear for path_words', () => {
  const PW_WORLD = `${DOCS}/level_worlds/path_words_1`;
  const PW_RECORDS = `${DOCS}/leaderboards/path_words/level_records/u1`;
  const PW_ROW = `${DOCS}/leaderboards/path_words/levels/u1`;
  const cells = (list: number[][]) => list.map(([row, col]) => ({ row, col }));
  // Blank centre cell at (1,1).
  const pwLevel = {
    id: 'path_words_1_01',
    size: 3,
    letters: ['c', 'a', 't', 'd', '', 'z', 'o', 'x', 'y'],
    targets: [
      { id: 'a', word: 'cat', start: { row: 0, col: 0 }, path: cells([[0, 0], [0, 1], [0, 2]]), colorIndex: 0 },
      { id: 'b', word: 'dox', start: { row: 1, col: 0 }, path: cells([[1, 0], [2, 0], [2, 1]]), colorIndex: 1 },
    ],
    definitions: {},
    targetSeconds: 30,
  };
  const pwWorld = (): Record<string, StoredFake> => ({
    [PW_WORLD]: { fields: encodeFields({ published: true, levels: [pwLevel] }), updateTime: 'W' },
  });
  const pwBody = (strokes: unknown, extra: Record<string, unknown> = {}) => ({
    gameId: 'path_words',
    levelId: 'path_words_1_01',
    timeSeconds: 12,
    usedHints: false,
    proof: { strokes },
    ...extra,
  });
  const stored = [
    { targetId: 'a', cells: [[0, 0], [0, 1], [0, 2]] },
    { targetId: 'b', cells: [[1, 0], [2, 0], [2, 1]] },
  ];

  it('accepts the stored paths and writes the board row', async () => {
    const fake = fakeFirestore(pwWorld());
    const res = await handleLevelClear(deps, 'u1', pwBody(stored));
    expect(res).toEqual({ status: 200, body: { accepted: true, improved: true } });
    expect(fake.gets).toEqual([[PW_WORLD, PW_RECORDS, PW_ROW]]);
    const [records, row] = fake.commits[0].writes as Write[];
    expect(records.update.name).toBe(PW_RECORDS);
    expect(row.update.name).toBe(PW_ROW);
    expect(row.update.fields).toMatchObject({ stars: { integerValue: '3' } });
  });

  it('accepts a different adjacent route that stays off the other words', async () => {
    const alt = {
      ...pwLevel,
      letters: ['c', 'a', 't', 'a', 'a', 'z', 'o', 'x', 'y'],
      targets: [
        { id: 'a', word: 'ca', start: { row: 0, col: 0 }, path: cells([[0, 0], [0, 1]]), colorIndex: 0 },
        { id: 'b', word: 'oxy', start: { row: 2, col: 0 }, path: cells([[2, 0], [2, 1], [2, 2]]), colorIndex: 1 },
      ],
    };
    fakeFirestore({
      [PW_WORLD]: { fields: encodeFields({ published: true, levels: [alt] }), updateTime: 'W' },
    });
    const res = await handleLevelClear(
      deps,
      'u1',
      pwBody([
        { targetId: 'a', cells: [[0, 0], [1, 0]] },
        { targetId: 'b', cells: [[2, 0], [2, 1], [2, 2]] },
      ]),
    );
    expect(res).toEqual({ status: 200, body: { accepted: true, improved: true } });
  });

  it('refuses a stroke reusing another target cell', async () => {
    // "ca" can also be spelled down (0,0)->(1,0), but (1,0) is the start of
    // "ax"; "ax" has a second route on row 2, so the strokes never overlap.
    const reuse = {
      ...pwLevel,
      letters: ['c', 'a', 'z', 'a', 'x', 'q', 'a', 'x', 'q'],
      targets: [
        { id: 'a', word: 'ca', start: { row: 0, col: 0 }, path: cells([[0, 0], [0, 1]]), colorIndex: 0 },
        { id: 'b', word: 'ax', start: { row: 1, col: 0 }, path: cells([[1, 0], [1, 1]]), colorIndex: 1 },
      ],
    };
    const world = (): Record<string, StoredFake> => ({
      [PW_WORLD]: { fields: encodeFields({ published: true, levels: [reuse] }), updateTime: 'W' },
    });
    const otherRoute = { targetId: 'b', cells: [[2, 0], [2, 1]] };

    fakeFirestore(world());
    const res = await handleLevelClear(
      deps,
      'u1',
      pwBody([{ targetId: 'a', cells: [[0, 0], [1, 0]] }, otherRoute]),
    );
    expect(res).toEqual({ status: 422, body: { error: 'bad_proof' } });

    // Control: the same "ax" route with "ca" on its stored path is fine, so
    // the refusal above is the cell reuse alone.
    fakeFirestore(world());
    const ok = await handleLevelClear(
      deps,
      'u1',
      pwBody([{ targetId: 'a', cells: [[0, 0], [0, 1]] }, otherRoute]),
    );
    expect(ok).toEqual({ status: 200, body: { accepted: true, improved: true } });
  });

  it('answers not_live for a missing level', async () => {
    fakeFirestore({});
    const res = await handleLevelClear(deps, 'u1', pwBody(stored));
    expect(res).toEqual({ status: 422, body: { error: 'not_live' } });
  });
});
