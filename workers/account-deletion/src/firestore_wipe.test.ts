import { describe, expect, it } from 'vitest';
import {
  allTimeLeaderboardPath,
  dailyEntryPath,
  issueReportsStructuredQuery,
} from './firestore_wipe';

describe('firestore paths', () => {
  it('all_time', () => {
    expect(allTimeLeaderboardPath('p', 'leaderboards', 'zip', 'u1')).toContain(
      '/leaderboards/zip/all_time/u1',
    );
  });
  it('daily entry', () => {
    expect(
      dailyEntryPath('p', 'leaderboards_debug', 'sudoku', '2026-10-09', 'u1'),
    ).toContain('/leaderboards_debug/sudoku/daily/2026-10-09/entries/u1');
  });
});

describe('issueReportsStructuredQuery', () => {
  it('orders by __name__ with limit for pagination', () => {
    const q = issueReportsStructuredQuery('u1') as {
      orderBy: unknown[];
      limit: number;
      startAt?: unknown;
    };
    expect(q.orderBy).toEqual([
      { field: { fieldPath: '__name__' }, direction: 'ASCENDING' },
    ]);
    expect(q.limit).toBe(300);
    expect(q.startAt).toBeUndefined();
  });

  it('uses startAt cursor after last doc', () => {
    const doc =
      'projects/p/databases/(default)/documents/issue_reports/r1';
    const q = issueReportsStructuredQuery('u1', doc) as {
      startAt: { values: unknown[]; before: boolean };
    };
    expect(q.startAt.before).toBe(false);
    expect(q.startAt.values).toEqual([{ referenceValue: doc }]);
  });
});
