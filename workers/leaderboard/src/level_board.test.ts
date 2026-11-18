import { describe, expect, it } from 'vitest';
import fixtureJson from './fixtures/app_proofs.json';
import {
  findLevel,
  levelBoardTotals,
  mergeLevelRecord,
  parseLevelClearBody,
} from './level_board';

const zip = (fixtureJson as unknown as { zip: { puzzle: Record<string, unknown> } }).zip.puzzle;

const body = {
  gameId: 'zip',
  levelId: 'zip_3_07',
  timeSeconds: 42,
  usedHints: false,
  proof: { path: [] },
  displayName: 'Ada',
};

describe('parseLevelClearBody', () => {
  it('accepts a valid body and reads the world from the level id', () => {
    expect(parseLevelClearBody(body)).toEqual({
      gameId: 'zip',
      levelId: 'zip_3_07',
      worldOrder: 3,
      timeSeconds: 42,
      usedHints: false,
      proof: { path: [] },
      identity: { displayName: 'Ada', photoUrl: null, avatarId: null },
    });
  });

  it('refuses a game outside the level games', () => {
    expect(parseLevelClearBody({ ...body, gameId: 'sudoku' })).toBeNull();
  });

  it('refuses a level id of the wrong shape', () => {
    for (const levelId of ['zip_3', 'zip_a_07', 'sudoku_3_07', 'zip_3_07x', 5, undefined]) {
      expect(parseLevelClearBody({ ...body, levelId })).toBeNull();
    }
  });

  it('refuses a time that is not a whole number', () => {
    for (const timeSeconds of [4.5, '42', NaN, 0, null]) {
      expect(parseLevelClearBody({ ...body, timeSeconds })).toBeNull();
    }
  });

  it('refuses hints that are not a boolean', () => {
    expect(parseLevelClearBody({ ...body, usedHints: 'no' })).toBeNull();
    expect(parseLevelClearBody({ ...body, usedHints: undefined })).toBeNull();
  });

  it('refuses a body that is not an object', () => {
    for (const bad of [null, [], 'x', 3]) expect(parseLevelClearBody(bad)).toBeNull();
  });
});

describe('findLevel', () => {
  const world = {
    published: true,
    levels: [{ id: 'zip_1_01', ...zip, targetSeconds: 30 }],
  };

  it('returns the puzzle and target for a published level', () => {
    const found = findLevel(world, 'zip_1_01');
    expect(found?.targetSeconds).toBe(30);
    expect(found?.puzzle.size).toBe(zip.size);
  });

  it('turns a missing target into null', () => {
    const noTarget = { published: true, levels: [{ id: 'zip_1_01', ...zip }] };
    expect(findLevel(noTarget, 'zip_1_01')?.targetSeconds).toBeNull();
  });

  it('is null for an unpublished world, a missing level and a missing doc', () => {
    expect(findLevel({ ...world, published: false }, 'zip_1_01')).toBeNull();
    expect(findLevel(world, 'zip_1_02')).toBeNull();
    expect(findLevel(null, 'zip_1_01')).toBeNull();
  });

  it('is null when the board does not parse', () => {
    const broken = { published: true, levels: [{ id: 'zip_1_01', size: 'x' }] };
    expect(findLevel(broken, 'zip_1_01')).toBeNull();
  });
});

describe('mergeLevelRecord', () => {
  it('counts a first clear as an improvement', () => {
    const merged = mergeLevelRecord({}, 'a', { stars: 2, bestSeconds: 30 });
    expect(merged).toEqual({ records: { a: { stars: 2, bestSeconds: 30 } }, improved: true });
  });

  it('leaves the same run alone', () => {
    const records = { a: { stars: 2, bestSeconds: 30 } };
    const merged = mergeLevelRecord(records, 'a', { stars: 2, bestSeconds: 30 });
    expect(merged.improved).toBe(false);
    expect(merged.records).toEqual(records);
  });

  it('keeps higher stars and lower time separately', () => {
    const faster = mergeLevelRecord({ a: { stars: 3, bestSeconds: 40 } }, 'a', {
      stars: 2,
      bestSeconds: 20,
    });
    expect(faster).toEqual({ records: { a: { stars: 3, bestSeconds: 20 } }, improved: true });
    const starrier = mergeLevelRecord({ a: { stars: 1, bestSeconds: 10 } }, 'a', {
      stars: 3,
      bestSeconds: 50,
    });
    expect(starrier.records.a).toEqual({ stars: 3, bestSeconds: 10 });
  });

  it('ignores a stored entry that is not valid', () => {
    const bads = [
      { stars: 4, bestSeconds: 10 },
      { stars: 0, bestSeconds: 10 },
      { stars: 2, bestSeconds: 0 },
    ];
    for (const bad of bads) {
      const merged = mergeLevelRecord({ a: bad }, 'a', { stars: 1, bestSeconds: 90 });
      expect(merged).toEqual({ records: { a: { stars: 1, bestSeconds: 90 } }, improved: true });
    }
  });

  it('does not mutate its input', () => {
    const records = { a: { stars: 1, bestSeconds: 10 } };
    mergeLevelRecord(records, 'a', { stars: 3, bestSeconds: 5 });
    expect(records).toEqual({ a: { stars: 1, bestSeconds: 10 } });
  });
});

describe('levelBoardTotals', () => {
  it('sums stars, levels and best times', () => {
    expect(
      levelBoardTotals({ a: { stars: 3, bestSeconds: 10 }, b: { stars: 2, bestSeconds: 25 } }),
    ).toEqual({ stars: 5, levelsCleared: 2, timeSeconds: 35 });
  });

  it('is all zeros for no records', () => {
    expect(levelBoardTotals({})).toEqual({ stars: 0, levelsCleared: 0, timeSeconds: 0 });
  });

  it('skips invalid stored entries', () => {
    expect(levelBoardTotals({ a: { stars: 9, bestSeconds: 10 } })).toEqual({
      stars: 0,
      levelsCleared: 0,
      timeSeconds: 0,
    });
  });
});
