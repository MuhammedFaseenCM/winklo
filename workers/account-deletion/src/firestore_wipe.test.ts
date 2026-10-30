import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  allTimeLeaderboardPath,
  DELETE_BATCH_SIZE,
  dailyActivityUserPath,
  dailyEntryPath,
  fieldStructuredQuery,
  leagueCodePath,
  uidStructuredQuery,
  USER_SUBCOLLECTIONS,
  weeklyEntryPath,
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
  it('weekly entry', () => {
    expect(weeklyEntryPath('p', 'leaderboards', 'zip', '2026-W42', 'u1')).toBe(
      `${DOCS}/leaderboards/zip/weekly/2026-W42/entries/u1`,
    );
  });
  it('league code', () => {
    expect(leagueCodePath('p', 'ABC234')).toBe(`${DOCS}/league_codes/ABC234`);
  });
  it('daily activity', () => {
    expect(dailyActivityUserPath('p', '2026-10-09', 'u1')).toBe(
      `${DOCS}/daily_activity/2026-10-09/users/u1`,
    );
  });
});

describe('fieldStructuredQuery', () => {
  it('finds leagues a uid belongs to', () => {
    const q = fieldStructuredQuery('leagues', 'memberUids', 'ARRAY_CONTAINS', 'u1') as {
      from: unknown[];
      where: { fieldFilter: { field: { fieldPath: string }; op: string } };
    };
    expect(q.from).toEqual([{ collectionId: 'leagues' }]);
    expect(q.where.fieldFilter.field.fieldPath).toBe('memberUids');
    expect(q.where.fieldFilter.op).toBe('ARRAY_CONTAINS');
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
type FakeLeague = { id: string; ownerUid: string; code: string; memberUids: string[] };

function fakeFirestore(opts: {
  zipDays?: string[];
  zipWeeks?: string[];
  activityDays?: string[];
  leagues?: FakeLeague[];
  batchStatus?: (index: number) => { code?: number };
}) {
  const deleted: string[] = [];
  const updates: Array<Record<string, unknown>> = [];
  const batchCalls: number[] = [];
  const listUrls: string[] = [];
  const fetchMock = vi.fn(async (input: string, init?: RequestInit) => {
    const url = new URL(input);
    const path = decodeURIComponent(url.pathname);
    if (init?.method === 'POST' && path.endsWith(':runQuery')) {
      const body = JSON.parse(String(init.body)) as {
        structuredQuery: {
          from: Array<{ collectionId: string }>;
          where: {
            fieldFilter: {
              field: { fieldPath: string };
              value: { stringValue: string };
            };
          };
        };
      };
      const collection = body.structuredQuery.from[0].collectionId;
      if (collection === 'leagues') {
        const { field, value } = body.structuredQuery.where.fieldFilter;
        const uid = value.stringValue;
        const matches = (opts.leagues ?? []).filter((l) =>
          field.fieldPath === 'ownerUid' ? l.ownerUid === uid : l.memberUids.includes(uid),
        );
        return Response.json(
          matches.map((l) => ({
            document: {
              name: `${DOCS}/leagues/${l.id}`,
              fields: {
                ownerUid: { stringValue: l.ownerUid },
                code: { stringValue: l.code },
              },
            },
          })),
        );
      }
      return Response.json([{ document: { name: `${DOCS}/${collection}/doc1` } }]);
    }
    if (init?.method === 'POST' && path.endsWith(':batchWrite')) {
      const body = JSON.parse(String(init.body)) as {
        writes: Array<{ delete?: string } & Record<string, unknown>>;
      };
      batchCalls.push(body.writes.length);
      for (const write of body.writes) {
        if (write.delete) deleted.push(write.delete);
        else updates.push(write);
      }
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
    if (path.endsWith('/leaderboards/zip/weekly')) {
      return phantom('leaderboards/zip/weekly', opts.zipWeeks);
    }
    if (path.endsWith('/daily_activity')) {
      return phantom('daily_activity', opts.activityDays);
    }
    if (path.endsWith('/users/u1/game_days')) {
      return Response.json({
        documents: [{ name: `${DOCS}/users/u1/game_days/zip_20261009` }],
      });
    }
    if (path.endsWith('/users/u1/level_progress')) {
      return Response.json({
        documents: [{ name: `${DOCS}/users/u1/level_progress/zip` }],
      });
    }
    return Response.json({});
  });
  vi.stubGlobal('fetch', fetchMock);
  return { deleted, updates, batchCalls, listUrls };
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
        `${DOCS}/users/u1/level_progress/zip`,
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
      const isDayList = /\/(daily|daily_activity|weekly)\?/.test(url);
      expect(url.includes('showMissing=true')).toBe(isDayList);
    }
  });

  it('deletes weekly entries under missing week docs, on the release root only', async () => {
    const fake = fakeFirestore({ zipWeeks: ['2026-W41', '2026-W42'] });

    await wipeUserFirestore({ projectId: 'p', accessToken: 't', uid: 'u1' });

    expect(fake.deleted).toEqual(
      expect.arrayContaining([
        `${DOCS}/leaderboards/zip/weekly/2026-W41/entries/u1`,
        `${DOCS}/leaderboards/zip/weekly/2026-W42/entries/u1`,
      ]),
    );
    expect(fake.listUrls.some((u) => u.includes('leaderboards_debug/zip/weekly'))).toBe(false);
  });

  it('deletes the leagues the user owns, with their codes, and leaves the others', async () => {
    const fake = fakeFirestore({
      leagues: [
        { id: 'mine', ownerUid: 'u1', code: 'ABC234', memberUids: ['u1', 'u2'] },
        { id: 'theirs', ownerUid: 'u9', code: 'XYZ234', memberUids: ['u9', 'u1'] },
        { id: 'other', ownerUid: 'u9', code: 'QRS234', memberUids: ['u9'] },
      ],
    });

    const result = await wipeUserFirestore({ projectId: 'p', accessToken: 't', uid: 'u1' });

    expect(result.ok).toBe(true);
    expect(fake.deleted).toEqual(
      expect.arrayContaining([`${DOCS}/leagues/mine`, `${DOCS}/league_codes/ABC234`]),
    );
    expect(fake.deleted).not.toContain(`${DOCS}/leagues/theirs`);
    expect(fake.deleted).not.toContain(`${DOCS}/league_codes/XYZ234`);
    expect(fake.updates).toEqual([
      {
        update: { name: `${DOCS}/leagues/theirs` },
        updateMask: { fieldPaths: [] },
        updateTransforms: [
          {
            fieldPath: 'memberUids',
            removeAllFromArray: { values: [{ stringValue: 'u1' }] },
          },
        ],
        currentDocument: { exists: true },
      },
    ]);
  });

  it('deletes in batches of DELETE_BATCH_SIZE', async () => {
    const zipDays = Array.from(
      { length: DELETE_BATCH_SIZE + 50 },
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

  it('wipes level progress with the other user subcollections', () => {
    expect(USER_SUBCOLLECTIONS).toContain('level_progress');
  });
});
