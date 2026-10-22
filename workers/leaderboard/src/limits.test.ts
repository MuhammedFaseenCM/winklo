import { describe, expect, it } from 'vitest';
import {
  ENTRY_FIELDS,
  GAMES,
  MAX_SECONDS,
  MIN_SECONDS,
  PUZZLE_COLLECTIONS,
  WEEKLY_FIELDS,
  isGameId,
} from './limits';

describe('limits', () => {
  it('has the three games, each with a minimum and a puzzle collection', () => {
    expect([...GAMES]).toEqual(['zip', 'path_words', 'sudoku']);
    for (const game of GAMES) {
      expect(MIN_SECONDS[game]).toBeGreaterThan(0);
      expect(PUZZLE_COLLECTIONS[game]).toMatch(/_levels$/);
    }
  });

  it('uses the spec minimums and a one-day ceiling', () => {
    expect(MIN_SECONDS).toEqual({ zip: 1, path_words: 1, sudoku: 1 });
    expect(MAX_SECONDS).toBe(86_400);
  });

  it('recognises game ids', () => {
    expect(isGameId('zip')).toBe(true);
    expect(isGameId('word_match')).toBe(false);
    expect(isGameId(undefined)).toBe(false);
  });

  it('lists the entry and weekly fields', () => {
    expect([...ENTRY_FIELDS].sort()).toEqual(
      [
        'timeSeconds',
        'updatedAt',
        'displayName',
        'photoUrl',
        'avatarId',
        'usedHints',
        'hadMistakes',
        'currentStreak',
      ].sort(),
    );
    expect([...WEEKLY_FIELDS].sort()).toEqual(
      [
        'displayName',
        'photoUrl',
        'avatarId',
        'days',
        'daysCleared',
        'totalSeconds',
        'updatedAt',
      ].sort(),
    );
  });
});
