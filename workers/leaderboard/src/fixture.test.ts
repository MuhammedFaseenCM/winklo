import { describe, expect, it } from 'vitest';
import fixtureJson from './fixtures/app_proofs.json';
import { checkProof } from './proofs';

type Case = { puzzle: Record<string, unknown>; proof: unknown };

const fixture = fixtureJson as unknown as Record<'zip' | 'sudoku' | 'path_words', Case>;

// The app builds these exact proofs (test/firestore/leaderboard_proof_fixture_test.dart).
describe('proofs the app sends', () => {
  for (const game of ['zip', 'sudoku', 'path_words'] as const) {
    it(`${game} passes`, () => {
      expect(checkProof(game, fixture[game].puzzle, fixture[game].proof)).toBe('ok');
    });
  }
});
