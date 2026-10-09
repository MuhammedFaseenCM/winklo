import { beforeEach, describe, expect, it, vi } from 'vitest';

import { type Env, runDeleteAccount, summarizeStatus } from './delete_account';

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

import { writeDeletionAudit } from './audit';
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

function envWith(avatarDelete: () => Promise<void>): Env {
  return {
    AVATARS: { delete: vi.fn(avatarDelete) },
    FIREBASE_PROJECT_ID: 'p',
    FIREBASE_SERVICE_ACCOUNT_JSON: '{}',
  } as unknown as Env;
}

describe('runDeleteAccount', () => {
  beforeEach(() => {
    vi.mocked(deleteAuthUser).mockReset();
    vi.mocked(wipeUserFirestore).mockReset();
    vi.mocked(writeDeletionAudit).mockClear();
  });

  it('deletes the Auth user last and succeeds when every step does', async () => {
    vi.mocked(wipeUserFirestore).mockResolvedValue({ ok: true, deleted: 3 });
    const env = envWith(async () => undefined);

    const result = await runDeleteAccount({ env, uid: 'u1', email: 'a@b.c' });

    expect(result).toEqual({ httpStatus: 200, body: { ok: true } });
    expect(deleteAuthUser).toHaveBeenCalledWith({
      projectId: 'p',
      accessToken: 'token',
      uid: 'u1',
    });
    expect(vi.mocked(writeDeletionAudit).mock.calls[0][0].status).toBe(
      'completed',
    );
  });

  it('skips auth delete when firestore wipe hard-fails', async () => {
    vi.mocked(wipeUserFirestore).mockResolvedValue({
      ok: false,
      errorMessage: 'firestore_wipe_failed',
    });
    const env = envWith(async () => undefined);

    const result = await runDeleteAccount({ env, uid: 'u1', email: 'a@b.c' });

    expect(deleteAuthUser).not.toHaveBeenCalled();
    expect(result.httpStatus).toBe(500);
    expect(result.body).toEqual({ error: 'delete_failed' });
  });

  it('keeps the Auth user so the player can retry when the avatar delete fails', async () => {
    vi.mocked(wipeUserFirestore).mockResolvedValue({ ok: true, deleted: 3 });
    const env = envWith(async () => {
      throw new Error('r2 down');
    });

    const result = await runDeleteAccount({ env, uid: 'u1', email: null });

    expect(deleteAuthUser).not.toHaveBeenCalled();
    expect(result).toEqual({ httpStatus: 500, body: { error: 'delete_failed' } });
    expect(vi.mocked(writeDeletionAudit).mock.calls[0][0].status).toBe(
      'partial',
    );
  });

  it('reports a failed Auth delete instead of success', async () => {
    vi.mocked(wipeUserFirestore).mockResolvedValue({ ok: true, deleted: 3 });
    vi.mocked(deleteAuthUser).mockRejectedValue(new Error('auth_delete_failed'));
    const env = envWith(async () => undefined);

    const result = await runDeleteAccount({ env, uid: 'u1', email: null });

    expect(result).toEqual({ httpStatus: 500, body: { error: 'delete_failed' } });
  });
});
