import { describe, expect, it } from 'vitest';
import fixtureJson from './fixtures/level_stars.json';
import { starsFor } from './level_stars';

type Case = {
  usedHints: boolean;
  seconds: number;
  targetSeconds: number | null;
  stars: number;
};

// The app's starsFor runs this same table (test/firestore/level_stars_fixture_test.dart).
describe('starsFor matches the app', () => {
  for (const c of (fixtureJson as { cases: Case[] }).cases) {
    it(`hints=${c.usedHints} seconds=${c.seconds} target=${c.targetSeconds} -> ${c.stars}`, () => {
      expect(starsFor(c.usedHints, c.seconds, c.targetSeconds)).toBe(c.stars);
    });
  }
});
