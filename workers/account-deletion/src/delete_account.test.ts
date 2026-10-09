import { describe, expect, it } from 'vitest';

import { summarizeStatus } from './delete_account';

describe('summarizeStatus', () => {
  it('completed when all true', () => {
    expect(
      summarizeStatus({ firestore: true, r2: true, auth: true }),
    ).toBe('completed');
  });
  it('failed when firestore and auth false', () => {
    expect(
      summarizeStatus({ firestore: false, r2: true, auth: false }),
    ).toBe('failed');
  });
  it('partial when some true some false', () => {
    expect(
      summarizeStatus({ firestore: true, r2: false, auth: true }),
    ).toBe('partial');
  });
});
