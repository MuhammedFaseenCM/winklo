import { describe, expect, it } from 'vitest';
import { hasEnoughNouns, normalizeNouns, MIN_NOUN_COUNT } from './nouns';

describe('normalizeNouns', () => {
  it('lowercases, filters length 3-5, dedupes, sorts', () => {
    expect(
      normalizeNouns(['Cat', 'TREE', 'ok', 'ab', 'toolong', 'cat', 'oak!']),
    ).toEqual(['cat', 'tree']);
  });

  it('accepts only array inputs', () => {
    expect(normalizeNouns(null)).toEqual([]);
    expect(normalizeNouns('cat')).toEqual([]);
  });
});

describe('hasEnoughNouns', () => {
  it(`requires at least ${MIN_NOUN_COUNT}`, () => {
    expect(hasEnoughNouns(Array(MIN_NOUN_COUNT - 1).fill('cat'))).toBe(false);
    expect(hasEnoughNouns(Array(MIN_NOUN_COUNT).fill('dog'))).toBe(true);
  });
});
