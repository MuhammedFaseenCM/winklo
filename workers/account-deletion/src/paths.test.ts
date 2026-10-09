import { describe, expect, it } from 'vitest';
import { avatarObjectKey, LEADERBOARD_GAMES } from './paths';

describe('paths', () => {
  it('avatar key', () => {
    expect(avatarObjectKey('abc')).toBe('avatars/abc.jpg');
  });
  it('games', () => {
    expect([...LEADERBOARD_GAMES]).toEqual(['zip', 'path_words', 'sudoku']);
  });
});
