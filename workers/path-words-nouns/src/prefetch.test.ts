import { describe, expect, it } from 'vitest';
import { prefetchDateIds } from './dates';

describe('prefetchDateIds', () => {
  it('returns UTC-1, UTC, UTC+1 compact ids', () => {
    const now = new Date(Date.UTC(2026, 9, 2, 12, 0, 0)); // Oct 2 UTC
    expect(prefetchDateIds(now)).toEqual(['20261001', '20261002', '20261003']);
  });
});
