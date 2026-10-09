import { beforeEach, describe, expect, it, vi } from 'vitest';

import { runDeleteAccount, summarizeStatus } from './delete_account';

vi.mock('./auth_delete', () => ({
  deleteAuthUser: vi.fn(),
}));
vi.mock('./firestore_wipe', () => ({
  wipeUserFirestore: vi.fn(),
}));
vi.mock('./google_auth', () => ({
  parseServiceAccountJson: vi.fn(() => ({
    client_email: 'e',
    private_key: 'k',
    project_id: 'p',
  })),
  getGoogleAccessToken: vi.fn(async () => 'token'),
}));
vi.mock('./audit', () => ({
  writeDeletionAudit: vi.fn(async () => undefined),
}));

import { deleteAuthUser } from './auth_delete';
import { wipeUserFirestore } from './firestore_wipe';

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

describe('runDeleteAccount', () => {
  beforeEach(() => {
    vi.mocked(deleteAuthUser).mockReset();
    vi.mocked(wipeUserFirestore).mockReset();
  });

  it('skips auth delete when firestore wipe hard-fails', async () => {
    vi.mocked(wipeUserFirestore).mockResolvedValue({
      ok: false,
      errorMessage: 'firestore_wipe_failed',
    });

    const env = {
      AVATARS: { delete: vi.fn(async () => undefined) },
      FIREBASE_PROJECT_ID: 'p',
      FIREBASE_SERVICE_ACCOUNT_JSON: '{}',
    } as unknown as import('./delete_account').Env;

    const result = await runDeleteAccount({
      env,
      uid: 'u1',
      email: 'a@b.c',
    });

    expect(deleteAuthUser).not.toHaveBeenCalled();
    expect(result.httpStatus).toBe(500);
    expect(result.body).toEqual({ error: 'delete_failed' });
  });
});
