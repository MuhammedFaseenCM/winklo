import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  allTimeLeaderboardPath,
  DELETE_BATCH_SIZE,
  dailyActivityUserPath,
  dailyEntryPath,
  uidStructuredQuery,
  wipeUserFirestore,
} from './firestore_wipe';

const DOCS = 'projects/p/databases/(default)/documents';

describe('firestore paths', () => {
  it('all_time', () => {
    expect(allTimeLeaderboardPath('p', 'leaderboards', 'zip', 'u1')).toBe(
      `${DOCS}/leaderboards/zip/all_time/u1`,
    );
  });
  it('daily entry', () => {
    expect(
      dailyEntryPath('p', 'leaderboards_debug', 'sudoku', '2026-10-09', 'u1'),
    ).toBe(`${DOCS}/leaderboards_debug/sudoku/daily/2026-10-09/entries/u1`);
  });
  it('daily activity', () => {
    expect(dailyActivityUserPath('p', '2026-10-09', 'u1')).toBe(
      `${DOCS}/daily_activity/2026-10-09/users/u1`,
    );
  });
});

describe('uidStructuredQuery', () => {
  it('filters the collection by uid, ordered by __name__ for pagination', () => {
    const q = uidStructuredQuery('client_errors', 'u1') as {
      from: unknown[];
      orderBy: unknown[];
      limit: number;
      startAt?: unknown;
    };
    expect(q.from).toEqual([{ collectionId: 'client_errors' }]);
    expect(q.orderBy).toEqual([
      { field: { fieldPath: '__name__' }, direction: 'ASCENDING' },
    ]);
    expect(q.limit).toBe(300);
    expect(q.startAt).toBeUndefined();
  });

  it('uses startAt cursor after last doc', () => {
    const doc = `${DOCS}/issue_reports/r1`;
    const q = uidStructuredQuery('issue_reports', 'u1', doc) as {
      startAt: { values: unknown[]; before: boolean };
    };
    expect(q.startAt.before).toBe(false);
    expect(q.startAt.values).toEqual([{ referenceValue: doc }]);
  });
});

/**
 * Fake Firestore REST API. Day docs under `daily` and `daily_activity` exist
 * only as parents of subcollections, so (as in production) a list returns
 * them only with `showMissing=true`.
 */
function fakeFirestore(opts: {
  zipDays?: string[];
  activityDays?: string[];
  batchStatus?: (index: number) => { code?: number };
}) {
  const deleted: string[] = [];
  const batchCalls: number[] = [];
  const listUrls: string[] = [];
  const fetchMock = vi.fn(async (input: string, init?: RequestInit) => {
    const url = new URL(input);
    const path = decodeURIComponent(url.pathname);
    if (init?.method === 'POST' && path.endsWith(':runQuery')) {
      const body = JSON.parse(String(init.body)) as {
        structuredQuery: { from: Array<{ collectionId: string }> };
      };
      const collection = body.structuredQuery.from[0].collectionId;
      return Response.json([{ document: { name: `${DOCS}/${collection}/doc1` } }]);
    }
    if (init?.method === 'POST' && path.endsWith(':batchWrite')) {
      const body = JSON.parse(String(init.body)) as {
        writes: Array<{ delete: string }>;
      };
      batchCalls.push(body.writes.length);
      deleted.push(...body.writes.map((w) => w.delete));
      return Response.json({
        writeResults: body.writes.map(() => ({})),
        status: body.writes.map((_, i) => opts.batchStatus?.(i) ?? {}),
      });
    }
    listUrls.push(input);
    const showMissing = url.searchParams.get('showMissing') === 'true';
    const phantom = (collection: string, ids: string[] = []) =>
      Response.json(
        showMissing
          ? { documents: ids.map((id) => ({ name: `${DOCS}/${collection}/${id}` })) }
          : {},
      );
    if (path.endsWith('/leaderboards/zip/daily')) {
      return phantom('leaderboards/zip/daily', opts.zipDays);
    }
    if (path.endsWith('/daily_activity')) {
      return phantom('daily_activity', opts.activityDays);
    }
    if (path.endsWith('/users/u1/game_days')) {
      return Response.json({
        documents: [{ name: `${DOCS}/users/u1/game_days/zip_20261009` }],
      });
    }
    return Response.json({});
  });
  vi.stubGlobal('fetch', fetchMock);
  return { deleted, batchCalls, listUrls };
}

describe('wipeUserFirestore', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('deletes daily leaderboard rows and app-open records under missing day docs', async () => {
    const fake = fakeFirestore({
      zipDays: ['2026-10-01', '2026-10-02'],
      activityDays: ['2026-10-07'],
    });

    const result = await wipeUserFirestore({
      projectId: 'p',
      accessToken: 't',
      uid: 'u1',
    });

    expect(result.ok).toBe(true);
    expect(fake.deleted).toEqual(
      expect.arrayContaining([
        `${DOCS}/users/u1`,
        `${DOCS}/users/u1/game_days/zip_20261009`,
        `${DOCS}/leaderboards/zip/all_time/u1`,
        `${DOCS}/leaderboards_debug/sudoku/all_time/u1`,
        `${DOCS}/leaderboards/zip/daily/2026-10-01/entries/u1`,
        `${DOCS}/leaderboards/zip/daily/2026-10-02/entries/u1`,
        `${DOCS}/daily_activity/2026-10-07/users/u1`,
        `${DOCS}/issue_reports/doc1`,
        `${DOCS}/client_errors/doc1`,
      ]),
    );
    expect(new Set(fake.deleted).size).toBe(fake.deleted.length);
  });

  it('asks for missing docs only when listing day collections', async () => {
    const fake = fakeFirestore({});

    await wipeUserFirestore({ projectId: 'p', accessToken: 't', uid: 'u1' });

    for (const url of fake.listUrls) {
      const isDayList = /\/daily(_activity)?\?/.test(url);
      expect(url.includes('showMissing=true')).toBe(isDayList);
    }
  });

  it('deletes in batches of DELETE_BATCH_SIZE', async () => {
    const zipDays = Array.from(
      { length: 150 },
      (_, i) => `2026-${String(1 + Math.floor(i / 28)).padStart(2, '0')}-${String(1 + (i % 28)).padStart(2, '0')}`,
    );
    const fake = fakeFirestore({ zipDays });

    const result = await wipeUserFirestore({
      projectId: 'p',
      accessToken: 't',
      uid: 'u1',
    });

    expect(result).toEqual({ ok: true, deleted: fake.deleted.length });
    expect(fake.batchCalls.length).toBeGreaterThan(1);
    expect(Math.max(...fake.batchCalls)).toBeLessThanOrEqual(DELETE_BATCH_SIZE);
  });

  it('fails when any delete in a batch fails', async () => {
    fakeFirestore({ batchStatus: (i) => (i === 0 ? { code: 7 } : {}) });

    const result = await wipeUserFirestore({
      projectId: 'p',
      accessToken: 't',
      uid: 'u1',
    });

    expect(result.ok).toBe(false);
  });

  it('refuses a uid that is not a Firebase uid', async () => {
    const fake = fakeFirestore({});

    const result = await wipeUserFirestore({
      projectId: 'p',
      accessToken: 't',
      uid: '../users/other',
    });

    expect(result).toEqual({ ok: false, errorMessage: 'invalid_uid' });
    expect(fake.deleted).toEqual([]);
  });
});
