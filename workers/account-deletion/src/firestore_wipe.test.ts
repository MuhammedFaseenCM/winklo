import { describe, expect, it } from 'vitest';
import { allTimeLeaderboardPath, dailyEntryPath } from './firestore_wipe';

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
